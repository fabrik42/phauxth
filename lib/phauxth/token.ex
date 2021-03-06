defmodule Phauxth.Token do
  @moduledoc """
  Api token based on the Phoenix token implementation.

  The data stored in the token is signed to prevent tampering
  but not encrypted. This means it is safe to store identification
  information (such as user IDs) but should not be used to store
  confidential information (such as credit card numbers).

  ## Key generator options

  The key generator has three options:

    * key_iterations - the number of iterations the key derivation function uses
      * the default is 1000
    * key_length - the length of the key, in bytes
      * the default is 32
    * key_digest - the hash algorithm that is used
      * the default is :sha256

  Note that the same key generator options should be used for signing
  and verifying tokens.
  """

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier
  alias Phauxth.Config

  @max_age 86_400

  @doc """
  Sign the token.
  """
  def sign(conn, data, opts \\ []) do
    secret = get_key_base(conn) |> get_secret(opts)

    %{data: data, signed: now_ms()}
    |> :erlang.term_to_binary()
    |> MessageVerifier.sign(secret)
  end

  @doc """
  Verify the token.

  ## Options

  In addition to the key generator options, there is one option:

    * max_age - the maximum age, in seconds, that the token is valid
      * the default is 86_400, which is one day
  """
  def verify(conn, token, opts \\ [])
  def verify(conn, token, opts) when is_binary(token) do
    secret = get_key_base(conn) |> get_secret(opts)
    max_age_ms = trunc(Keyword.get(opts, :max_age, @max_age) * 1000)

    case MessageVerifier.verify(token, secret) do
      {:ok, message} ->
        %{data: data, signed: signed} = Plug.Crypto.safe_binary_to_term(message)

        if (signed + max_age_ms) < now_ms() do
          {:error, "expired token"}
        else
          {:ok, data}
        end
      :error ->
        {:error, "invalid token"}
    end
  end
  def verify(_conn, nil, _opts), do: {:error, "missing token"}

  defp get_key_base(%{secret_key_base: key}), do: validate_secret(key)
  defp get_key_base(endpoint) do
    endpoint.config(:secret_key_base)
  end

  defp validate_secret(nil) do
    raise ArgumentError, "The secret_key_base has not been set"
  end
  defp validate_secret(key) when byte_size(key) < 20 do
    raise ArgumentError, "The secret_key_base is too short. It should be at least 20 bytes long."
  end
  defp validate_secret(key), do: key

  defp get_secret(secret_key_base, opts) do
    key_opts = [iterations: opts[:key_iterations] || 1000,
                length: validate_len(opts[:key_length]),
                digest: validate_digest(opts[:key_digest]),
                cache: Plug.Keys]
    KeyGenerator.generate(secret_key_base, Config.token_salt, key_opts)
  end

  defp validate_len(nil), do: 20
  defp validate_len(len) when len < 20 do
    raise ArgumentError, "The key_length is too short. It should be at least 20 bytes long."
  end
  defp validate_len(len), do: len

  defp validate_digest(nil), do: :sha256
  defp validate_digest(digest) when digest in [:sha256, :sha512], do: digest
  defp validate_digest(digest) do
    raise ArgumentError, "Phauxth.Token does not support #{digest}"
  end

  defp now_ms, do: System.system_time(:millisecond)
end
