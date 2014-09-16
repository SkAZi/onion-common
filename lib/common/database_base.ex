defmodule Onion.RPC.Database.Base do
    defmacro __using__(_options) do
        quote do

            def fields do
                @fields
                |> Enum.map(fn({key, val})-> 
                    res = [:eq, :lt, :gt, :gte, :lte, :like]
                    |> Enum.map fn(method)-> 
                        {:"#{key}__#{method}", val[:type]}
                    end

                    [{key, val[:type]}, 
                     {:"#{key}__notnull", :bool}, 
                     {:"#{key}__isnull", :bool} 
                    | res ]
                end)
                |> List.flatten
            end

            def atomise(dict) do
                dict
                |> Enum.map(fn({key, val}) when is_binary(key)-> {String.to_existing_atom(key), val}; (kv)-> kv end)
                |> Enum.into %{}
            end


            def new(), do: new(%{}, true)
            def new(keys), do: new(keys, true)

            def new(keys, dirty) when is_list(keys), do: new(keys |> Enum.into(%{}), dirty)
            def new(keys, dirty) do
                umerge(__MODULE__.__struct__, keys)
                    |> umerge(%{__dirty__: dirty})
                    |> check_validity
            end

            defp to_struct(item) when is_map(item), do: new(item, false)
            defp to_struct(list) when is_list(list) do
                Enum.map list, fn(item)-> new(item, false) end
            end

            defp umerge(obj, []), do: obj
            defp umerge(obj, keys) do
                Map.merge(obj, keys |> atomise)
            end

            def merge(obj, keys) do
                umerge(obj, keys) |> umerge(%{__dirty__: true}) |> check_validity
            end

            defp check_validity(nil), do: nil
            defp check_validity(obj) do
                case Enum.any?(obj, fn({_, {:error}})-> true; (_)-> false end) do
                    true -> nil
                    false -> obj
                end
            end

            defp is_dirty(%{__dirty__: dirty}), do: dirty

            def get_list(obj) do
                Enum.filter_map obj,
                    fn({key, val})->
                        String.starts_with?(Atom.to_string(key), "__") == false
                    end,
                    fn(item)-> item end
            end

            defp get_key_vals(obj) do
                get_list(obj) |> Enum.reduce {[], []}, fn({key, val}, {keys, vals})->
                    {[key | keys], [val | vals]}
                end
            end

            defp insert_placeholder(list) do
                String.duplicate(",?", Enum.count(list))
                |> String.lstrip(?,)
            end

            defp update_placeholder(list) do
                Enum.join(list, "=?, ") <> "=?"
            end

            defp pk_placeholder() do
                @primary_keys
                |> Enum.map fn(key)->
                    "#{key}=?"
                end
            end

            defp slice_pks(obj) do
                @primary_keys
                |> Enum.map(fn(key)-> {key, obj[key]} end)
                |> Enum.into(%{})
            end

            def divide_pks(obj) do
                Enum.reduce(obj, {%{}, %{}}, 
                    fn({key, val}, {pk, npk}) when key in @primary_keys -> 
                        {Dict.put(pk, key, val), npk}
                    ({:__struct__, _}, ret) -> ret
                    ({key, val}, {pk, npk}) ->
                        {pk, Dict.put(npk, key, val)}
                end)
            end

            defp select_pks(obj) do
                @primary_keys
                |> Enum.map fn(key)->
                    obj[key]
                end
            end

            def all_pk?(obj) do
                @primary_keys
                |> Enum.all? fn(key)->
                    obj[key] != nil
                end
            end


            def args_to_filter(args) when is_list(args), do: args_to_filter(args, [])
            def args_to_filter(args) when is_map(args), do: args_to_filter( Map.to_list(args), [])
            def args_to_filter(args) when is_binary(args), do: args_to_filter(String.split(args, "&"), [])

            def args_to_filter([], res), do: res
            def args_to_filter([str|tail], res) when is_binary(str) do
                [key, value] = String.split(str, "=")
                args_to_filter([{key, value}|tail], res)
            end
            def args_to_filter([{key, value}|tail], res) do
                key = cond do
                    is_atom(key) -> Atom.to_string(key)
                    true -> key
                end

                case String.contains?(key, "__") do
                    false -> args_to_filter(tail, [{String.to_existing_atom(key), :eq, value} | res])
                    true ->
                        case String.split(key, "__") do
                            [nkey, "eq"] ->  args_to_filter(tail, [{String.to_existing_atom(nkey), :eq, value}  | res])
                            [nkey, "lt"] ->  args_to_filter(tail, [{String.to_existing_atom(nkey), :lt, value}  | res])
                            [nkey, "gt"] ->  args_to_filter(tail, [{String.to_existing_atom(nkey), :gt, value}  | res])
                            [nkey, "gte"] -> args_to_filter(tail, [{String.to_existing_atom(nkey), :gte, value} | res])
                            [nkey, "lte"] -> args_to_filter(tail, [{String.to_existing_atom(nkey), :lte, value} | res])
                            [nkey, "like"] -> args_to_filter(tail, [{String.to_existing_atom(nkey), :like, value} | res])
                            [nkey, "isnull"] -> args_to_filter(tail, [{String.to_existing_atom(nkey), :isnull, nil} | res])
                            [nkey, "notnull"] -> args_to_filter(tail, [{String.to_existing_atom(nkey), :notnull, nil} | res])
                            [nkey, "crc"] -> args_to_filter(tail, [{String.to_existing_atom(nkey), :crc, value} | res])
                            #["orderby"] -> 
                            #["limit"] -> 
                            #["offset"] -> 
                            _ -> args_to_filter(tail, [{String.to_existing_atom(key), :eq, value} | res])
                        end
                end
            end

        end
    end
end