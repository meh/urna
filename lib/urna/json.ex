defmodule Urna.JSON do
  use Urna.Adapter

  def accept?("application/json"), do: true
  def accept?(_),                  do: false

  def encode(_, value) do
    { "application/json", Poison.encode!(value) }
  end

  def decode(_, string) do
    Poison.decode(string)
  end
end
