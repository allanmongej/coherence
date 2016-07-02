defmodule Coherence.ConfirmationController do
  use Phoenix.Controller
  alias Coherence.Config
  import Ecto.Query
  import Coherence.ControllerHelpers
  require Logger
  use Timex

  def edit(conn, params) do
    user_schema = Config.user_schema
    token = params["id"]
    user = where(user_schema, [u], u.confirmation_token == ^token)
    |> Config.repo.one
    case user do
      nil ->
        changeset = user_schema.changeset(user_schema.__struct__)
        conn
        |> put_flash(:error, "Invalid confirmation token.")
        |> redirect(to: logged_out_url(conn))
      user ->
        if expired? user.confirmation_send_at do
          conn
          |> put_flash(:error, "Confirmation token expired.")
          |> redirect(to: logged_out_url(conn))
        else
          changeset = user_schema.changeset(user, %{
            confirmation_token: nil,
            confirmed_at: Ecto.DateTime.utc,
            })
          case Config.repo.update(changeset) do
            {:ok, _user} ->
              conn
              |> put_flash(:info, "User confirmed successfully.")
              |> redirect(to: logged_out_url(conn))
            {:error, changeset} ->
              conn
              |> put_flash(:error, "Problem confirming user. Please contact the system administrator.")
              |> redirect(to: logged_out_url(conn))
          end
        end
    end
  end

  def expired?(datetime) do
    expire_on? = datetime
    |> Ecto.DateTime.to_erl
    |> Timex.DateTime.from_erl
    |> Timex.shift(days: Config.confirmation_token_expire_days)
    not Timex.before?(Timex.DateTime.now, expire_on?)
  end

end
