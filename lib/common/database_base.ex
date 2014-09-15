defmodule Onion.Common.Database.Base do
    defmacro __using__(_options) do
        quote do

            def new(), do: new(%{}, true)
            def new(keys), do: new(keys, true)

            defp new(keys, dirty) when is_list(keys), do: new(keys |> Enum.into(%{}), dirty)
            defp new(keys, dirty) do
                umerge(__MODULE__.__struct__, keys)
                    |> umerge(%{__dirty__: dirty})
                    |> check_validity
            end

            defp to_struct(item) when is_map(item), do: new(item, false)
            defp to_struct(list) when is_list(list) do
                Enum.map list, fn(item)-> new(item, false) end
            end

            defp umerge(obj, []), do: obj
            defp umerge(obj, keys) when is_list(keys), do: merge(obj, keys |> Enum.into %{})
            defp umerge(obj, keys) do
                Map.merge(obj, keys)
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

            defp select_pks(obj) do
                @primary_keys
                |> Enum.map fn(key)->
                    obj[key]
                end
            end

            defp all_pk?(obj) do
                @primary_keys
                |> Enum.all? fn(key)->
                    obj[key] != nil
                end
            end

        end
    end
end