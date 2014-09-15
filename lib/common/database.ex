defmodule Onion.Common.Database do
    defmacro __using__(_options) do
        quote do

            defmacro deftable name, args \\ [], code do
                quote do
                    defmodule unquote(name) do
                        @args unquote(args)
                        @table_name   Dict.get unquote(args), :name,
                            Atom.to_string(unquote(name))
                            |> String.split(".", parts: 2)
                            |> List.last
                            |> String.replace(".", "")
                            |> AfJsonREST.Utils.camel_to_snake()

                        @table_type   Dict.get unquote(args), :type, :mysql
                        @primary_keys Dict.get unquote(args), :pk, [:id]

                        field_names = []
                        fields = []
                        structure = [__dirty__: false]

                        unquote(code)

                        @fields fields
                        @field_names field_names
                        use Onion.Common.Database.Base
                        case @table_type do
                            :mysql -> use Onion.Common.Database.MySQL
                            _ -> raise "Undefined Database Type"
                        end

                        @derive [Access, Enumerable]
                        defstruct structure
                    end
                end
            end # aftable

            defmacro deffield name, args \\ [] do
                quote location: :keep do
                    fields = [ { unquote(name), unquote(args) } | fields]
                    field_names = [unquote(name) | field_names]

                    structure = [ { unquote(name), (fn
                        (%{autoincrement: true})-> nil
                        (%{null: true})-> nil
                        (%{default: default})-> default
                        (%{null: false})-> {:error}
                    end).(Enum.into(unquote(args), %{})) } | structure ]

                end #quote location: :keep do
            end

        end
    end # __using__
end