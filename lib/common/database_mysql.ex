defmodule Onion.Common.Database.MySQL do
    defmacro __using__(_options) do
        quote do
            defp escape([]), do: []
            defp escape([?'|str]), do: [92,?'|escape(str)]
            defp escape([c|str]), do: [c|escape(str)]

            defp quote_if_needed(v) when is_integer(v), do: v
            defp quote_if_needed(v) when is_binary(v), do: [[?'|escape(String.to_char_list(v))]|[?']]
            defp quote_if_needed(v) when is_list(v) do
                v |> Enum.map(&quote_if_needed/1)
            end

            defp prep_argument(arg) when is_list(arg), do: [[?(| String.to_char_list Enum.join quote_if_needed(arg), "," ]|[?)]]
            defp prep_argument(arg) when is_binary(arg), do: [[?'|escape(String.to_char_list(arg))]|[?']]
            defp prep_argument(arg) when is_integer(arg), do: Integer.to_char_list arg
            defp prep_argument(arg) when is_float(arg), do: Float.to_char_list arg
            defp prep_argument(nil), do: 'NULL'
            defp prep_argument(:undefined), do: 'NULL'

            defp in_query([], _), do: []
            defp in_query(sql, args) when is_binary(sql), do: in_query(String.to_char_list(sql), args)
            defp in_query([??|sql], [arg|arg_tail]), do: [prep_argument(arg)|in_query(sql, arg_tail)]
            defp in_query([s|sql], args), do: [s|in_query(sql, args)]

            def query(sql, args), do: List.to_string List.flatten in_query sql, args

            defp get_filters(args) do
                args_to_filter(args)
                |> Enum.filter_map(fn({key, op, _})->
                    key in @field_names
                end, fn
                    ({key, :eq, val})-> {"#{key}=?", val}
                    ({key, :lt, val})-> {"#{key}<?", val}
                    ({key, :gt, val})-> {"#{key}>?", val}
                    ({key, :lte, val})-> {"#{key}<=?", val}
                    ({key, :gte, val})-> {"#{key}>=?", val}
                    ({key, :like, val})-> {"#{key} LIKE ?"}
                    ({key, :isnull, _})-> {"#{key} IS NULL"}
                    ({key, :notnull, _})-> {"#{key} IS NOT NULL"}
                end)
                |> Enum.reduce {[], [], %{}}, fn
                    ({key, val}, {keys, vals, opts})-> {[key|keys], [val|vals], opts}
                    ({key}, {keys, vals, opts})-> {[key|keys], vals, opts}
                end
            end

            def insert(obj=%{__dirty__: false}) when is_map(obj), do: obj
            def insert(obj) when is_list(obj), do: insert(obj |> Enum.into %{})
            def insert(obj) when is_map(obj) do
                {keys, values} = get_key_vals(obj)
                query("INSERT INTO #{@table_name} (#{keys |> Enum.join(",")})
                    VALUES (#{insert_placeholder(keys)});", values)
            end

            def update(up) when is_list(up), do: update(up |> Enum.into %{})
            def update(up) when is_map(up) do
                update(slice_pks(up), up)
            end
            def update(obj, up) when is_map(obj) do
                {keys, values} = get_key_vals(up)
                values = values ++ select_pks(obj)

                query("UPDATE INTO #{@table_name} SET #{update_placeholder(keys)}
                    WHERE #{Enum.join(pk_placeholder(), " AND ")}", values)
            end

            def get(values) when is_list(values) do
                query("SELECT #{Enum.join(@field_names, ",")} FROM #{@table_name}
                    WHERE #{Enum.join(pk_placeholder(), " AND ")} LIMIT 1", values)
            end
            def get(values), do: get([values])

            def select(filters) do
                {keys, values, _opts} = get_filters(filters)
                q = query("SELECT #{Enum.join(@field_names, ",")} FROM #{@table_name}
                    WHERE #{Enum.join(keys, " AND ")}", values)

                q = case filters[:order_by] do
                    nil -> q
                    order when is_binary(order) -> "#{q} ORDER BY #{order}"
                    order -> "#{q} ORDER BY #{Enum.join(order, ", ")}"
                end

                case {filters[:limit], filters[:offset]} do
                    {nil, nil} -> q
                    {limit, nil} -> "#{q} LIMIT #{limit}"
                    {nil, offset} -> "#{q} OFFSET #{offset}"
                    {limit, offset} -> "#{q} LIMIT #{limit},#{offset}"
                end
            end

            def delete(obj) when is_list(obj), do: delete(obj |> Enum.into %{})
            def delete(obj) when is_map(obj) do
                case obj[:__struct__] == __MODULE__ do
                    true ->
                        cond do
                            %{__dirty__: true} = obj -> nil
                            all_pk?(obj) -> nil
                            true -> query("DELETE FROM #{@table_name}
                                WHERE #{Enum.join(pk_placeholder(), " AND ")}", select_pks(obj))
                        end
                    false ->
                        {keys, values, _opts} = get_filters(obj)
                        query("DELETE FROM #{@table_name}
                            WHERE #{Enum.join(keys, " AND ")}", values)
                end
            end

            def transaction(cmd_list) do
                "START TRANSACTION; #{Enum.join(cmd_list, ";")}; COMMIT TRANSACTION;"
            end
        end
    end
end
