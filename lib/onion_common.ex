defmodule Onion.Common do
    import Onion
    import Onion.Common.DataValidator, only: [key_to_bin_dict: 1]

    def baseHttpRpc(opts \\ []) do
        [BaseHttpData, HttpPostData, ValidateArgs.init(opts)]
    end

    def flashHttpRpc(opts \\ []) do
        [BaseHttpData, HttpPostData, DumbFlashResponse, ValidateArgs.init(opts)]
    end


    defmiddleware BaseHttpData do

        @default [:headers, :method, :host, :port, :path, :qs_vals, :bindings]

        def process(:in, state, opts) do
            opts = case opts do
                nil -> []
                [] -> @default
                opts -> opts
            end

            {ret, cowboy} = Enum.reduce opts, {%{}, state.cowboy}, fn(key, {ret, req})->
                {val, req} = apply(:cowboy_req, key, [req])

                val = cond do
                    key in [:headers, :qs_vals, :bindings] -> val |> key_to_bin_dict
                    true -> val
                end

                {Dict.put(ret, key, val), req}
            end

            {:ok, body, cowboy} = :cowboy_req.body(cowboy)
            ret = Dict.put(ret, :body, body)
            %{state | cowboy: cowboy, request: Dict.merge(state.request, ret)}
        end

    end


    defmiddleware HttpPostData do

        defp process_json(body) do
            case :jiffy.decode(body, [:return_maps]) do
                {:error, _} -> %{} 
                res -> res |> key_to_bin_dict
            end
        end

        defp process_urlencoded(body) do
            :cow_qs.parse_qs(body) |> key_to_bin_dict
        end

        def process(:in, state = %{ request: %{body: body, method: "POST", headers: %{"content-type" => "application/json"}} }, _opts) do
            put_in state, [:request, :post], process_json(body)
        end

        def process(:in, state = %{ request: %{body: body, method: "POST", headers: %{"content-type" => "application/x-www-form-urlencoded"}} }, _opts) do
            put_in state, [:request, :post], process_urlencoded(body)
        end

        def process(:in, state, _opts) do
            put_in state, [:request, :post], %{}
        end


        def process(:out, state = %{ request: %{qs_vals: qs, headers: %{"accept" => accept}}, response: response }, _opts) do
            is_json = qs["type"] == "json" or accept == "*/*" or String.contains?(accept, "application/json")
            is_text = true

            cond do
                is_json -> 
                    res = :jiffy.encode(response[:body])

                    res = case qs["callback"] do
                        nil -> res
                        name -> "#{name}(#{res})"
                    end

                    reply(state, 200, res, [{"content-type", "application/json; charset=UTF-8"}])

                is_text -> 
                    res = case response[:body] do
                        nil -> ""
                        val when is_binary(val) -> val
                        val -> inspect(val)
                    end

                    reply(state, 200, res)
            end
        end

    end


    defmiddleware ValidateArgs do

        def process(:in, state = %{ middlewares: middlewares, request: request }, opts) do
            args = request[:bindings]
                    |> Dict.merge(request[:qs_vals])
                    |> Dict.merge(request[:post])

            case Onion.Common.DataValidator.validate(args, opts[:args] || [], opts[:optional] || []) do
                {:ok, args} -> 
                    put_in(state, [:request, :args], args)

                {:error, error} -> 
                    put_in(state, [:request, :args], %{})
                    |> reply(400, "Bad request #{inspect error}")
                    |> break
            end  
        end

    end


    defmiddleware DumbFlashResponse do
        def process(:out, state = %{request: %{ args: args }, response: response}, _opts) do
            res = Enum.filter(args, fn({"__" <> _rest, _})-> true; (x)-> false end) |> Enum.into(%{})

            case response[:code] < 300 do
                true -> 
                    reply(state, 200, Dict.merge(res, %{ result: response[:body], error: :null, code: response[:code] }))
                false ->
                    reply(state, 200, Dict.merge(res, %{ result: :null, error: response[:body], code: response[:code] }))
            end
        end
    end

end
