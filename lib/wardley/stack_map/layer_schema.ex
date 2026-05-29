defmodule Wardley.StackMap.LayerSchema do
  @moduledoc """
  The canonical layer schema for the software stack embedding space.

  This is the fixed reference frame. All parsers, renderers, and fingerprint
  comparisons write to and read from this schema. It is versioned so that
  fingerprints computed against different schema versions can be detected
  and recomputed.

  ## Frame geometry

  The y-axis runs from 0.0 (physics / hardware) to 1.0 (human intent).
  The software stack occupies roughly 0.2–1.0. Hardware occupies 0.0–0.2.
  Unknown nodes float to 0.5 (mid-frame) and are visually distinguished.

      1.0  ┌──────────────────────────────┐
           │  experience   (user intent)  │
           │  application  (product logic)│
           │  platform     (shared svcs)  │
           │  persistence  (data layer)   │
           │  transport    (net/protocol) │
           │  runtime      (VM/lang)      │
      0.2  │  os           (kernel/POSIX) │
           ├──────────────────────────────┤  hardware boundary
      0.1  │  firmware     (drivers)      │
      0.0  │  silicon      (ISA/physics)  │
           └──────────────────────────────┘

  ## Layer definitions

  Each layer has:
    - `:id`          canonical string key used everywhere
    - `:label`       human display name
    - `:y_mid`       midpoint of the layer band (0.0–1.0)
    - `:y_range`     {min, max} band extent
    - `:description` what belongs here
    - `:hardware`    true if below the software/hardware boundary

  ## Schema version

  Bump `:version` any time layers are added, removed, or y-values shift.
  Fingerprints embed the schema version so stale comparisons can be flagged.
  """

  @version "1.0"

  @layers [
    %{
      id: "experience",
      label: "Experience",
      y_mid: 0.95,
      y_range: {0.90, 1.00},
      hardware: false,
      description: "User-facing product surface — UI, personas, journeys, end-user value"
    },
    %{
      id: "application",
      label: "Application",
      y_mid: 0.82,
      y_range: {0.74, 0.90},
      hardware: false,
      description: "Application frameworks and business logic — Rails, Phoenix, Django, Next.js"
    },
    %{
      id: "platform",
      label: "Platform",
      y_mid: 0.68,
      y_range: {0.60, 0.74},
      hardware: false,
      description: "Shared platform services — web servers, auth, email, job queues, pub/sub"
    },
    %{
      id: "persistence",
      label: "Persistence",
      y_mid: 0.54,
      y_range: {0.46, 0.60},
      hardware: false,
      description: "Data storage and retrieval — databases, ORMs, caches, file stores"
    },
    %{
      id: "transport",
      label: "Transport",
      y_mid: 0.40,
      y_range: {0.32, 0.46},
      hardware: false,
      description: "Network, protocol, and serialization — HTTP clients, DNS, TLS, codecs, JSON"
    },
    %{
      id: "runtime",
      label: "Runtime",
      y_mid: 0.27,
      y_range: {0.20, 0.32},
      hardware: false,
      description: "Language runtimes and VMs — BEAM, JVM, V8, CPython, libc, stdlib"
    },
    %{
      id: "os",
      label: "Operating System",
      y_mid: 0.15,
      y_range: {0.10, 0.20},
      hardware: false,
      description: "Kernel, POSIX layer, system calls, package managers (apt, brew)"
    },
    %{
      id: "firmware",
      label: "Firmware",
      y_mid: 0.07,
      y_range: {0.03, 0.10},
      hardware: true,
      description: "Device drivers, firmware, BIOS/UEFI, embedded software"
    },
    %{
      id: "silicon",
      label: "Silicon",
      y_mid: 0.02,
      y_range: {0.00, 0.03},
      hardware: true,
      description: "ISA, CPU microarchitecture, physics — the fixed bottom of the frame"
    },
    %{
      id: "unknown",
      label: "Unknown",
      y_mid: 0.50,
      y_range: {0.46, 0.54},
      hardware: false,
      description: "Uncategorized — floats to mid-frame pending classification"
    }
  ]

  # Ordered list for fingerprint vector — unknown excluded (it's a sentinel, not a real layer)
  @vector_layers ~w(experience application platform persistence transport runtime os firmware silicon)

  # ── Public API ─────────────────────────────────────────────────────────────

  def version, do: @version

  def layers, do: @layers

  def vector_layers, do: @vector_layers

  @doc "Look up a layer definition by id. Returns nil if not found."
  def get(id) do
    Enum.find(@layers, fn l -> l.id == id end)
  end

  @doc "Return the canonical y_mid for a layer id. Unknown → 0.5."
  def y_mid(id) do
    case get(id) do
      nil -> 0.5
      layer -> layer.y_mid
    end
  end

  @doc """
  Convert a canonical y_mid (0.0–1.0) to a map percentage (0–100).
  The map's y-axis uses 0–100 internally; this bridges the two.
  """
  def y_to_pct(y), do: y * 100.0

  @doc "All non-hardware layer ids, ordered top to bottom."
  def software_layer_ids do
    @layers
    |> Enum.reject(&(&1.hardware or &1.id == "unknown"))
    |> Enum.sort_by(& &1.y_mid, :desc)
    |> Enum.map(& &1.id)
  end

  @doc "All hardware layer ids, ordered top to bottom."
  def hardware_layer_ids do
    @layers
    |> Enum.filter(& &1.hardware)
    |> Enum.sort_by(& &1.y_mid, :desc)
    |> Enum.map(& &1.id)
  end

  @doc """
  Validate that a layer id is known. Returns :ok or {:error, :unknown_layer}.
  """
  def validate(id) do
    if Enum.any?(@layers, fn l -> l.id == id end), do: :ok, else: {:error, :unknown_layer}
  end

  @doc """
  Migration map from the old informal layer names to canonical ids.
  Used by parsers transitioning from the old taxonomy.
  """
  def legacy_migration do
    %{
      # old name        => canonical id
      "application" => "application",
      # frontend frameworks are application-layer
      "frontend" => "application",
      # web servers / plug / rack = platform
      "web" => "platform",
      "data" => "persistence",
      # pubsub, dns_cluster = platform
      "infrastructure" => "platform",
      "network" => "transport",
      # telemetry = platform service
      "observability" => "platform",
      # JSON, MIME, codecs = transport-adjacent
      "serialization" => "transport",
      # build tools live at runtime layer
      "build" => "runtime",
      "runtime" => "runtime",
      "unknown" => "unknown"
    }
  end
end
