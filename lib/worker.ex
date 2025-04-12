defmodule Meteosup.Worker do
  use GenServer
  @base_url "https://api.open-meteo.com/v1/forecast?"

  ## Client  API
  ## Client API are the function that I can call to execute work by the gen server
  ##

  def get_temperature(pid, location) do
    GenServer.call(pid, {:location, location})
  end

  def get_stats(pid) do
    GenServer.call(pid, :get_stats)
  end

  def reset_stats(pid) do
    GenServer.cast(pid, :reset_stats)
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  ## GenServer callbacks
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    # init state is a empty map
    {:ok, %{}}
  end

  def handle_call({:location, location}, _from, state) do
    case action(location) do
      {:ok, weather} ->
        new_state = update_stats(state, location)
        {:reply, {:ok, weather}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, state}
  end

  def handle_cast(:reset_stats, _state) do
    {:noreply, %{}}
  end

  def handle_info(msg, state) do
    IO.puts("Worker received message: #{inspect(msg)}")
    {:noreply, state}
  end

  def terminate(reason, state) do
    inspect(state)
    :ok
  end

  ## Helper functions

  def get_weather(lat, lon) do
    # Get the weather

    resp =
      Req.get!(@base_url,
        params: [
          latitude: lat,
          longitude: lon,
          current: "temperature_2m,windspeed_10m"
        ]
      )

    resp
  end

  def parse_response(resp) do
    # Parse the response
    case resp do
      %{status: 200} ->
        %{body: %{"current" => %{"temperature_2m" => temp, "windspeed_10m" => wind}}} = resp
        string_representation = "Wind: #{wind}, Temperature: #{temp}"
        {:ok, string_representation}

      _ ->
        {:error, "Something went wrong connecting to Weather API"}
    end
  end

  def action(location) do
    {lat, lon} = location

    get_weather(lat, lon)
    |> parse_response()
  end

  def update_stats(old_stats, location) do
    # Update the stats
    case Map.has_key?(old_stats, location) do
      true -> Map.update!(old_stats, location, fn x -> x + 1 end)
      false -> Map.put_new(old_stats, location, 1)
    end
  end
end
