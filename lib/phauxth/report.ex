defmodule Phauxth.Report do
  @moduledoc """
  Log and report information and errors.
  """

  alias Phauxth.{Config, Log}

  @messages %{
    "user already confirmed" => "The user has already been confirmed",
    "no reset token found" => "The user has not been sent a reset token"
  }

  @doc """
  Log information about the user and return {:ok, user}.
  """
  def verify_ok(user, message) do
    Log.info(%Log{user: user.id, message: message})
    {:ok, Map.drop(user, Config.drop_user_keys)}
  end

  @doc """
  Log the error and return a generic error message.
  """
  def verify_error(nil), do: verify_error("no user found")
  def verify_error(message) do
    Log.warn(%Log{message: message})
    {:error, "Invalid credentials"}
  end

  @doc """
  Log the user information and error, and then return an error message.
  """
  def verify_error(user, message) do
    Log.warn(%Log{user: user.id, message: message})
    {:error, @messages[message]}
  end
end
