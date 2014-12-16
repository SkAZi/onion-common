defmodule Onion.Common.DataValidator do

    defp to_atom(value) when is_atom(value), do: {:ok, value }
    defp to_atom(value) when is_binary(value), do: {:ok, String.to_atom(value) }
    defp to_atom(value), do: {:error, value}

    defp to_existing_atom(value) when is_atom(value), do: {:ok, value }
    defp to_existing_atom(value) when is_binary(value), do: {:ok, String.to_existing_atom(value) }
    defp to_existing_atom(value), do: {:error, value}


    defp to_binary(value) when is_atom(value), do: {:ok, Atom.to_string(value) }
    defp to_binary(value) when is_binary(value), do: {:ok, value }
    defp to_binary(value) when is_integer(value), do: {:ok, Integer.to_string(value) }
    defp to_binary(value) when is_float(value), do: {:ok, Float.to_string(value) }
    defp to_binary(value), do: {:error, value}


    defp to_integer(value) when is_integer(value), do: {:ok, value }
    defp to_integer(value) when is_float(value), do: {:ok, trunc(value) }
    defp to_integer(value) when is_binary(value) do
        case Integer.parse(value) do
            :error -> {:error, value}
            {val, _} -> {:ok, val}            
        end
    end
    defp to_integer(value), do: {:error, value}

    defp to_bool(0), do: {:ok, false}
    defp to_bool(""), do: {:ok, false}
    defp to_bool("no"), do: {:ok, false}
    defp to_bool("false"), do: {:ok, false}
    defp to_bool(false), do: {:ok, false}
    defp to_bool(:no), do: {:ok, false}
    defp to_bool(value) when is_binary(value), do: {:ok, true}
    defp to_bool(value) when is_atom(value), do: {:ok, true}
    defp to_bool(value) when is_integer(value), do: {:ok, true}

    defp to_float(value) when is_float(value), do: {:ok, value }
    defp to_float(value) when is_integer(value), do: {:ok, value * 1.0 }
    defp to_float(value) when is_binary(value) do
        case Float.parse(value) do
            :error -> {:error, value}
            {val, _} -> {:ok, val}            
        end
    end
    defp to_float(value), do: {:error, value}

    defp to_list(value) when is_list(value), do: {:ok, value}
    defp to_list(value) when is_integer(value) or is_float(value) or is_atom(value), do: {:ok, [value]}
    defp to_list(value) when is_binary(value), do: {:ok, String.split(value, ",") }
    defp to_list(value), do: {:error, value}
    
    defp to_map(value) when is_map(value), do: {:ok, value}
    defp to_map(value), do: {:error, value}

    defp to_any(value), do: {:ok, value}

    defp to_int_list(a={:error, _}), do: a
    defp to_int_list({:ok, val}), do: to_int_list(val)
    defp to_int_list(value) when is_list(value) do 
        case (value |> Enum.reduce {:ok, []}, 
            fn(item, {:ok, array}) -> 
                case to_integer(item) do
                    {:ok, new_item} -> {:ok, [new_item|array]}
                    {:error, _} -> :error
                end;
            (_, :error) -> :error
            end) do
            :error -> {:error, value}
            {:ok, val} -> {:ok, Enum.reverse(val)}
        end
    end

    defp to_bin_list(a={:error, _}), do: a
    defp to_bin_list({:ok, val}), do: to_bin_list(val)
    defp to_bin_list(value) when is_list(value) do 
        case (value |> Enum.reduce {:ok, []}, 
            fn(item, {:ok, array}) -> 
                case to_binary(item) do
                    {:ok, new_item} -> {:ok, [new_item|array]}
                    {:error, _} -> :error
                end;
            (_, :error) -> :error
            end) do
            :error -> {:error, value}
            {:ok, val} -> {:ok, Enum.reverse(val) }
        end
    end
    
    defp to_atom_list(a={:error, _}), do: a
    defp to_atom_list({:ok, val}), do: to_atom_list(val)
    defp to_atom_list(value) when is_list(value) do 
        case (value |> Enum.reduce {:ok, []}, 
            fn(item, {:ok, array}) -> 
                case to_atom(item) do
                    {:ok, new_item} -> {:ok, [new_item|array]}
                    {:error, _} -> :error
                end;
            (_, :error) -> :error
            end) do
            :error -> {:error, value}
            {:ok, val} -> {:ok, Enum.reverse(val) }
        end
    end

    defp to_existing_atom_list(a={:error, _}), do: a
    defp to_existing_atom_list({:ok, val}), do: to_existing_atom_list(val)
    defp to_existing_atom_list(value) when is_list(value) do 
        case (value |> Enum.reduce {:ok, []}, 
            fn(item, {:ok, array}) -> 
                case to_existing_atom(item) do
                    {:ok, new_item} -> {:ok, [new_item|array]}
                    {:error, _} -> :error
                end;
            (_, :error) -> :error
            end) do
            :error -> {:error, value}
            {:ok, val} -> {:ok, Enum.reverse(val) }
        end
    end

    defp to_float_list(a={:error, _}), do: a
    defp to_float_list({:ok, val}), do: to_float_list(val)
    defp to_float_list(value) when is_list(value) do 
        case (value |> Enum.reduce {:ok, []}, 
            fn(item, {:ok, array}) -> 
                case to_float(item) do
                    {:ok, new_item} -> {:ok, [new_item|array]}
                    {:error, _} -> :error
                end;
            (_, :error) -> :error 
            end) do
            :error -> {:error, value}
            {:ok, val} -> {:ok, Enum.reverse(val) }
        end
    end

    defp process(value, :atom), do: to_atom(value)
    defp process(value, :exatom), do: to_existing_atom(value)
    defp process(value, :existing_atom), do: to_existing_atom(value)
    defp process(value, :map), do: to_map(value)
    defp process(value, :bool), do: to_bool(value)
    defp process(value, :boolean), do: to_bool(value)
    defp process(value, :float), do: to_float(value)
    defp process(value, :timestamp), do: to_integer(value)
    defp process(value, :integer), do: to_integer(value)
    defp process(value, :int), do: to_integer(value)
    defp process(value, :binary), do: to_binary(value)
    defp process(value, :bin), do: to_binary(value)
    defp process(value, :string), do: to_binary(value)
    defp process(value, :str), do: to_binary(value)
    defp process(value, :list), do: to_list(value)

    defp process(value, :timestamp_list), do: to_list(value) |> to_int_list
    defp process(value, :integer_list), do: to_list(value) |> to_int_list
    defp process(value, :int_list), do: to_list(value) |> to_int_list
    defp process(value, :float_list), do: to_list(value) |> to_float_list
    defp process(value, :bin_list), do: to_list(value) |> to_bin_list
    defp process(value, :str_list), do: to_list(value) |> to_bin_list
    defp process(value, :string_list), do: to_list(value) |> to_bin_list
    defp process(value, :binary_list), do: to_list(value) |> to_bin_list
    defp process(value, :atom_list), do: to_list(value) |> to_atom_list
    defp process(value, :exatom_list), do: to_list(value) |> to_existing_atom_list
    defp process(value, :existing_atom_list), do: to_list(value) |> to_existing_atom_list
    defp process(value, :any_list), do: to_list(value)
    defp process(value, :any), do: to_any(value)

    defp process(value, _type), do: {:unprocess, value}

    defp process_mandatory([], _, res), do: {:ok, res}
    defp process_mandatory([{key, type}|tail], dict, res) do
        case Dict.has_key?(dict, key) do
            false -> :error
            true ->
                case process(dict[key], type) do
                    {:ok, new_value} -> process_mandatory(tail, dict, Dict.put(res, key, new_value))
                    _ -> :error
                end
        end
    end

    defp process_optional([], _, res), do: {:ok, res}
    defp process_optional([{key, [{ type, default }] }|tail], dict, res), do: process_optional([{key, { type, default } }|tail], dict, res)
    defp process_optional([{key, { type, default } }|tail], dict, res) do
        case Dict.has_key?(dict, key) do
            false -> process_optional(tail, dict, Dict.put(res, key, default))
            true ->
                case process(dict[key], type) do
                    {:ok, new_value} -> process_optional(tail, dict, Dict.put(res, key, new_value))
                    _ -> :error
                end
        end
    end
    defp process_optional([{key, type}|tail], dict, res) do
        case Dict.has_key?(dict, key) do
            false -> process_optional(tail, dict, res)
            true ->
                case process(dict[key], type) do
                    {:ok, new_value} -> process_optional(tail, dict, Dict.put(res, key, new_value))
                    _ -> :error
                end
        end
    end

    
    defp process_other([], res), do: res
    
    defp process_other([{key, value}|dict], res) do
        case Dict.has_key?(res, key) do
            false -> process_other(dict, Dict.put(res, key, value))
            true -> process_other(dict, res)
        end
    end

    def validate(dict, mandatory, optional \\ [], strict \\ false) do
        case process_mandatory(key_to_bin(mandatory), dict, %{}) do
            {:ok, new_dict} -> 
                case process_optional(key_to_bin(optional), dict, new_dict) do
                    {:ok, new_dict2} -> 
                        case strict || false do
                            false -> {:ok, process_other(dict |> Enum.into([]), new_dict2)}
                            true -> {:ok, new_dict2}
                        end
                    :error -> {:error, dict}
                end
            :error -> {:error, dict}
        end
    end

    def key_to_bin(dict), do: dict |> Enum.map(fn({key, value}) when is_atom(key) -> {Atom.to_string(key), value}; (item) -> item end)    
    def key_to_bin_dict(dict), do: key_to_bin(dict) |> Enum.into %{}

end
