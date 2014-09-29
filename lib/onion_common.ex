defmodule Onion.Common do
    import Onion
    import Onion.Common.DataValidator, only: [key_to_bin_dict: 1]

    def baseHttpRpc(opts \\ []) do
        [BaseHttpData, HttpPostData, ValidateArgs.init(opts)]
    end

    def flashHttpRpc(opts \\ []) do
        [BaseHttpData, HttpPostData, DumbFlashResponse, ValidateArgs.init(opts)]
    end


    defmiddleware BaseHttpData, chain_type: :only do

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


    defmiddleware HttpPostData, chain_type: :only, required: [BaseHttpData] do

        defp process_json(""), do: %{}
        defp process_json(nil), do: %{}
        defp process_json(body) do
            case :jiffy.decode(body, [:return_maps, :use_nil]) do
                {:error, _} -> %{} 
                res -> res |> key_to_bin_dict
            end
        end

        defp process_urlencoded(body) do
            :cow_qs.parse_qs(body) |> key_to_bin_dict
        end

        def process(:in, state = %{ request: %{body: body, headers: %{"content-type" => "application/json" <> _}} }, _opts) do
            put_in state, [:request, :post], process_json(body)
        end

        def process(:in, state = %{ request: %{body: body, headers: %{"content-type" => "application/x-www-form-urlencoded" <> _}} }, _opts) do
            put_in state, [:request, :post], process_urlencoded(body)
        end

        def process(:in, state, _opts) do
            put_in state, [:request, :post], %{}
        end


        def process(:out, state = %{ request: %{qs_vals: qs, headers: %{"accept" => accept}}, response: response}, _opts) do
            is_text = String.contains?(accept, "plain/text")
            is_html = String.contains?(accept, "text/html")
            is_json = true
            cond do
                is_text or is_html -> 
                    res = case response[:body] do
                        nil -> ""
                        val when is_binary(val) -> val
                        val -> inspect(val)
                    end

                    headers = cond do
                        is_text -> [{"content-type", "plain/text; charset=UTF-8"}]
                        is_html -> [{"content-type", "plain/html; charset=UTF-8"}]
                    end

                    reply(state, 200, res, headers)

                is_json -> 
                    res = :jiffy.encode(response[:body], [:use_nil])

                    res = case qs["_callback"] do
                        nil -> res
                        name -> "#{name}(#{res})"
                    end

                    reply(state, 200, res, [{"content-type", "application/json; charset=UTF-8"}])
            end
        end

    end


    defmiddleware ValidateArgs, chain_type: :args_only, required: [BaseHttpData, HttpPostData] do

        def process(:in, state = %{ request: request }, opts) do
            args = (request[:args] || %{})
                    |> Dict.merge(request[:bindings])
                    |> Dict.merge(request[:qs_vals])
                    |> Dict.merge(request[:post])

            case Onion.Common.DataValidator.validate(args, opts[:args] || [], opts[:optional] || [], opts[:strict]) do
                {:ok, args} -> 
                    put_in(state, [:request, :args], args)

                {:error, error} -> 
                    put_in(state, [:request, :args], %{})
                    |> reply(400, "Bad request #{inspect error}")
                    |> break
            end  
        end

    end


    defmiddleware DumbFlashResponse, chain_type: :only, required: [ValidateArgs] do
        def process(:out, state = %{request: %{ args: args }, response: response}, _opts) do
            res = Enum.filter(args, fn({"__" <> _, _})-> true; (_)-> false end) |> Enum.into(%{})

            case response[:code] < 300 do
                true -> 
                    reply(state, 200, Dict.merge(res, %{ result: response[:body], error: :null, code: response[:code] }))
                false ->
                    reply(state, 200, Dict.merge(res, %{ result: :null, error: response[:body], code: response[:code] }))
            end
        end
    end


    defmiddleware Session, chain_type: :only, required: [] do

        defp create_session(state) do
            session = U.uuid
            state 
                |> put_in([:request, :session], session) 
                |> set_coockie("session", session)
        end

        def process(:in, state = %{cowboy: req}, _) do
            case :cowboy_req.cookie("session", req) do
                    {:undefined, _} -> create_session(state)
                    {"", _} -> create_session(state)
                    {session, _} -> state |> put_in [:request, :session], session
            end
        end

    end
    

    defmiddleware Wtf, chain_type: :only, required: [] do

        def process(:in, state, opts) do
            case Mix.env do
                :prod -> state
                _ -> 
                    probability = (opts[:probability] || 10) / 100
                    errors = opts[:errors] || [
                        {200, 42},
                        {200, "Ha-ha gocha!"},
                        {401, "Session broken"},
                        {402, "Something went wrong"},
                        {403, "Not allowed"},
                        {404, "Not found"},
                        {500, "Server error"},
                        {502, "Server busy"},
                        {502, "Server absolutely busy"},
                    ]

                    <<a :: 32, b :: 32, c :: 32 >> = :crypto.rand_bytes(12)
                    :random.seed(a, b, c)

                    cond do
                        :random.uniform() < probability -> 
                            {num, res} = Enum.at(errors, :random.uniform(length(errors))-1)
                            reply(state, num, res) |> break
                        :random.uniform() < probability * 3 ->
                            :timer.sleep 4000                    
                            state
                        :random.uniform() < probability * 1 ->
                            :timer.sleep 10000
                            state
                        true -> state
                    end
            end
        end
    end

end
