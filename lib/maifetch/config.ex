defmodule Maifetch.Config do
  @moduledoc false

  defstruct access_token: nil, config_file: nil, score_count: 4, logo_size: 20

  @aliases %{
    "-a" => :access_token,
    "-t" => :access_token,
    "--access-token" => :access_token,
    "--token" => :access_token,
    "-c" => :config_file,
    "--config-file" => :config_file,
    "-s" => :score_count,
    "--score-count" => :score_count,
    "-l" => :logo_size,
    "--logo-size" => :logo_size
  }

  def load(argv \\ System.argv(), env \\ &System.get_env/1) do
    with {:ok, cli} <- parse_argv(argv),
         path <-
           cli[:config_file] || first_env(env, ["MAITEA_CONFIG_FILE", "MAIFETCH_CONFIG_FILE"]) ||
             default_config_path(),
         {:ok, file} <- load_file_config(path),
         {:ok, score_count} <-
           int_value(
             cli[:score_count] || first_env(env, ["MAITEA_SCORE_COUNT", "MAIFETCH_SCORE_COUNT"]) ||
               file["scoreCount"] || 4,
             "score count"
           ),
         {:ok, logo_size} <-
           int_value(
             cli[:logo_size] || first_env(env, ["MAITEA_LOGO_SIZE", "MAIFETCH_LOGO_SIZE"]) ||
               file["logoSize"] || 20,
             "logo size"
           ),
         token <-
           cli[:access_token] || first_env(env, ["MAITEA_TOKEN", "MAIFETCH_TOKEN"]) ||
             file["accessToken"],
         :ok <- validate_token(token),
         :ok <- validate_score_count(score_count) do
      {:ok,
       %__MODULE__{
         access_token: token,
         config_file: path,
         score_count: score_count,
         logo_size: logo_size
       }}
    end
  end

  defp parse_argv(argv), do: parse_argv(argv, %{})
  defp parse_argv([], acc), do: {:ok, acc}

  defp parse_argv([flag, value | rest], acc) do
    case Map.fetch(@aliases, flag) do
      {:ok, key} -> parse_argv(rest, Map.put(acc, key, value))
      :error -> {:error, "unknown argument: #{flag}\n\n#{usage()}"}
    end
  end

  defp parse_argv(["--help" | _], _acc), do: {:error, usage()}
  defp parse_argv(["-h" | _], _acc), do: {:error, usage()}
  defp parse_argv([unknown | _], _acc), do: {:error, "unknown argument: #{unknown}\n\n#{usage()}"}

  def usage do
    """
    maifetch - a really lazy fetch tool for maitea

    Options:
      -a, -t, --access-token, --token TOKEN
      -c, --config-file PATH
      -s, --score-count COUNT
      -l, --logo-size SIZE
      -h, --help
    """
  end

  defp load_file_config(nil), do: {:ok, %{}}

  defp load_file_config(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, raw} -> Jason.decode(raw)
        {:error, reason} -> {:error, "could not open #{path}: #{inspect(reason)}"}
      end
    else
      {:ok, %{}}
    end
  end

  defp first_env(env, names) do
    Enum.find_value(names, fn name ->
      case env.(name) do
        value when is_binary(value) ->
          value = String.trim(value)
          if value == "", do: nil, else: value

        _ ->
          nil
      end
    end)
  end

  defp int_value(value, _label) when is_integer(value), do: {:ok, value}

  defp int_value(value, label) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "#{label} must be an integer"}
    end
  end

  defp int_value(_value, label), do: {:error, "#{label} must be an integer"}

  defp validate_token(value) when is_binary(value) do
    if String.trim(value) == "", do: {:error, "access token is required"}, else: :ok
  end

  defp validate_token(_), do: {:error, "access token is required"}

  defp validate_score_count(count) when count <= 12 and count >= 0, do: :ok
  defp validate_score_count(_), do: {:error, "score count cannot be higher than 12"}

  def default_config_path do
    case :os.type() do
      {:win32, _} ->
        Path.join(System.get_env("APPDATA") || System.user_home!(), "maifetch.json")

      {:unix, :darwin} ->
        Path.join([System.user_home!(), "Library", "Application Support", "maifetch.json"])

      _ ->
        Path.join(
          System.get_env("XDG_CONFIG_HOME") || Path.join(System.user_home!(), ".config"),
          "maifetch.json"
        )
    end
  end
end
