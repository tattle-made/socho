defmodule SochoWeb.SettingsLive.Branding do
  use SochoWeb, :live_view

  alias Socho.AppSettings

  @impl true
  def mount(_params, _session, socket) do
    branding = AppSettings.get_branding()

    {:ok,
     assign(socket,
       logo_url: branding["logo_url"] || "",
       primary_color: branding["primary_color"] || "#000000",
       background_color: branding["background_color"] || "#ffffff"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-xl mx-auto p-6 space-y-6">
        <h1 class="text-2xl font-bold">App Branding</h1>
        <p class="text-sm opacity-60 -mt-4">
          Applied to all participant-facing surveys across every client.
        </p>

        <div class="card bg-base-200 shadow p-6">
          <form phx-submit="save" phx-change="preview" class="space-y-5">
            <div class="form-control">
              <label class="label"><span class="label-text font-medium">Logo URL</span></label>
              <input
                type="url"
                name="branding[logo_url]"
                class="input input-bordered w-full"
                placeholder="https://example.com/logo.png"
                value={@logo_url}
              />
              <p class="text-xs opacity-50 mt-1">Must be a publicly accessible image URL.</p>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label"><span class="label-text font-medium">Primary color</span></label>
                <div class="flex gap-2 items-center">
                  <input
                    type="color"
                    name="branding[primary_color]"
                    value={@primary_color}
                    class="w-10 h-10 rounded border border-base-300 cursor-pointer p-0.5"
                  />
                  <input
                    type="text"
                    name="branding[primary_color_hex]"
                    value={@primary_color}
                    class="input input-bordered input-sm flex-1 font-mono"
                    placeholder="#000000"
                    phx-blur="sync_hex"
                    phx-value-field="primary_color"
                  />
                </div>
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text font-medium">Background color</span></label>
                <div class="flex gap-2 items-center">
                  <input
                    type="color"
                    name="branding[background_color]"
                    value={@background_color}
                    class="w-10 h-10 rounded border border-base-300 cursor-pointer p-0.5"
                  />
                  <input
                    type="text"
                    name="branding[background_color_hex]"
                    value={@background_color}
                    class="input input-bordered input-sm flex-1 font-mono"
                    placeholder="#ffffff"
                    phx-blur="sync_hex"
                    phx-value-field="background_color"
                  />
                </div>
              </div>
            </div>

            <%!-- Live preview --%>
            <div>
              <p class="text-xs font-medium opacity-50 uppercase tracking-wider mb-2">Preview</p>
              <div
                class="rounded-lg border border-base-300 p-4 space-y-3"
                style={"background-color: #{@background_color};"}
              >
                <div class="flex items-center gap-3">
                  <img
                    :if={@logo_url != ""}
                    src={@logo_url}
                    class="h-8 object-contain"
                    alt="Logo preview"
                    onerror="this.style.display='none'"
                  />
                  <span :if={@logo_url == ""} class="text-xs opacity-40 italic">No logo set</span>
                </div>
                <div class="h-2 w-24 rounded" style={"background-color: #{@primary_color};"} />
                <p class="text-xs opacity-40">Survey content appears here</p>
                <button
                  type="button"
                  class="px-4 py-1.5 rounded text-white text-sm"
                  style={"background-color: #{@primary_color};"}
                >
                  Next
                </button>
              </div>
            </div>

            <div>
              <button type="submit" class="btn btn-primary">Save Branding</button>
            </div>
          </form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("preview", %{"branding" => b}, socket) do
    {:noreply,
     assign(socket,
       logo_url: b["logo_url"] || "",
       primary_color: coerce_color(b["primary_color"] || b["primary_color_hex"], socket.assigns.primary_color),
       background_color: coerce_color(b["background_color"] || b["background_color_hex"], socket.assigns.background_color)
     )}
  end

  def handle_event("preview", _params, socket), do: {:noreply, socket}

  def handle_event("sync_hex", %{"field" => field, "value" => val}, socket) do
    if valid_color?(val) do
      {:noreply, assign(socket, String.to_existing_atom(field), val)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save", %{"branding" => b}, socket) do
    branding = %{
      "logo_url" => String.trim(b["logo_url"] || ""),
      "primary_color" => coerce_color(b["primary_color"] || b["primary_color_hex"], socket.assigns.primary_color),
      "background_color" => coerce_color(b["background_color"] || b["background_color_hex"], socket.assigns.background_color)
    }

    case AppSettings.update_branding(branding) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Branding saved.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save branding.")}
    end
  end

  defp coerce_color(val, fallback) do
    if valid_color?(val), do: val, else: fallback
  end

  defp valid_color?(val) when is_binary(val), do: Regex.match?(~r/^#[0-9a-fA-F]{6}$/, val)
  defp valid_color?(_), do: false
end
