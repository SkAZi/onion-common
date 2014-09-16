defmodule Onion.RPS.Utils do

    def camel_to_snake(str, sn \\ "_"), do: 
        camel_to_snake(String.to_char_list(str), sn, [])
    def camel_to_snake([], sn, [head|tail]), do: 
        [Enum.reverse(head)|tail] |> Enum.reverse |> Enum.join(sn) |> String.downcase
    def camel_to_snake([char|tail], sn, []) do
        camel_to_snake(tail, sn, [[char]])
    end
    def camel_to_snake([char|tail], sn, [last|other]) do
        c = List.to_string([char])
        case String.downcase(c) == c do
            true -> camel_to_snake(tail, sn, [[char|last]|other])
            false -> camel_to_snake(tail, sn, [[char]|[List.to_string(Enum.reverse(last))|other]])
        end
    end

    def snake_to_camel(str, char \\ "_"), do:
        String.split(str, char) |> Enum.map(&String.capitalize/1) |> Enum.join("")
end