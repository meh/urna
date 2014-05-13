defmodule Urna.JSON do
  use Urna.Adapter
  use Jazz

  def accept?("application/json"), do: true
  def accept?(_),                  do: false

  def encode(_, value) do
    { "application/json", JSON.encode!(value) }
  end

  def decode(_, string) do
    JSON.decode(string)
  end
end
