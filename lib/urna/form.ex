defmodule Urna.Form do
  use Urna.Adapter

  def accept?("application/x-www-form-urlencoded"), do: true
  def accept?(_),                                   do: false

  def encode(_, value) do
    { "application/x-www-form-urlencoded", URI.encode_query(value) }
  end

  def decode(_, string) do
    { :ok, URI.decode_query(string, []) }
  end
end
