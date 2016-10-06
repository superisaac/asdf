defmodule Asdf.Util do
  import Phoenix.Controller
  
  def error_json(conn, error_msg) do
    json conn, %{ok: false, error: error_msg}
  end

  def ok_json(conn, data) when is_map(data) do
    json conn, data |> Map.put(:ok, true)
  end

  def parse_int(nil, default), do: default
  def parse_int("", default), do: default
  def parse_int(str, default) do
    try do
      String.to_integer(str)
    rescue
      ArgumentError -> default
    end
  end
  def parse_int(str) do
    parse_int(str, 0)
  end

  def parse_uint(str, default) do
    r = parse_int(str, default)
    if r < 0 do
      default
    else
      r
    end    
  end
  def parse_uint(str) do
    parse_uint(str, 0)
  end


  def encode_password(password) do
    salt = :crypto.strong_rand_bytes(16)
    hash = :crypto.hash(:sha256, salt <> password)
    Base.encode16(salt, case: :lower) <> "$" <> Base.encode16(hash, case: :lower)
  end

  def make_signature(nonce, botid, secret) do
    hash = :crypto.hash(:sha256, nonce <> botid <> secret)
    Base.encode16(hash, case: :lower)
  end

  def generate_nonce(cnt \\ 12) do
    n = :crypto.strong_rand_bytes(cnt)
    Base.encode16(n, case: :lower)
  end

  def check_password(encoded, password) do
    [hex_salt, hex_hash] = encoded |> String.split("$")
    {:ok, salt} = Base.decode16(hex_salt, case: :lower)
    {:ok, hash} = Base.decode16(hex_hash, case: :lower)
    case :crypto.hash(:sha256, salt <> password) do
      ^hash -> true
      _ -> false
    end
  end

  # Password prompt that hides input by every 1ms
  # clearing the line with stderr
  # copied from https://github.com/hexpm/hex/blob/1523f44e8966d77a2c71738629912ad59627b870/lib/mix/hex/utils.ex#L32-L58
  def password_get(prompt, false) do
    IO.gets(prompt <> " ") |> String.trim()
  end
  def password_get(prompt, true) do
    pid   = spawn_link(fn -> loop(prompt) end)
    ref   = make_ref()
    value = IO.gets(prompt <> " ")

    send pid, {:done, self(), ref}
    receive do: ({:done, ^pid, ^ref}  -> :ok)

    value |> String.trim()
  end

  defp loop(prompt) do
    receive do
      {:done, parent, ref} ->
        send parent, {:done, self, ref}
        IO.write :standard_error, "\e[2K\r"
    after
      1 ->
        IO.write :standard_error, "\e[2K\r#{prompt} "
        loop(prompt)
    end
  end

  def parse_entity("#"<>str) do
    case parse_double_ident(str) do
      {:int_id, int_id} ->
        {:room_id, int_id}
      {:double_name, name, sub_name} ->
        {:room, name, sub_name}
      _ -> nil
    end
  end
  def parse_entity("@"<>str) do
    case parse_double_ident(str) do
      {:int_id, int_id} ->
        {:user_id, int_id}
      {:double_name, name, sub_name} ->
        {:bot, name, sub_name}
      {:name, name} ->
        {:user, name}
      _ -> nil
    end
  end
  def parse_entity(_str), do: nil
  
  def valid_ident(nil), do: nil
  def valid_ident(""), do: nil
  def valid_ident(str) do
    reg_ident = ~r{^(?<ident>[a-z][a-z0-9\_\-\.]*)$}
    case Regex.named_captures(reg_ident, str) do
      %{"ident"=> ident} -> ident
      _ -> nil
    end
  end

  def parse_double_ident(str) do
    reg_room = ~r{^(?<name>[a-z][a-z0-9\_\-\.]*)(\/(?<sub_name>[a-z][a-z0-9\_\-\.]*))?|(?<int_id>\d+)$}
    case Regex.named_captures(reg_room, str) do
      %{"name" => "", "sub_name" => "", "int_id" => int_id} ->
        {int_id, _} = Integer.parse(int_id)
        {:int_id, int_id}
      %{"name"=> name, "sub_name" => "", "int_id"=> ""} when name != "" ->
        {:name, name}
      %{"name"=> name, "sub_name" => sub_name, "int_id"=> ""} ->
        {:double_name, name, sub_name}
      _ -> nil
    end
  end

  def merge_url(conn, url) do
    portstr =
    case conn.port do
      nil -> ""
      x when is_integer(x) -> ":#{x}"
      _ -> ""
    end
    base = "#{conn.scheme}://#{conn.host}#{portstr}"
    URI.merge(base, url)
    |> URI.to_string
  end

end
