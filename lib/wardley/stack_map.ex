defmodule Wardley.StackMap do
  @moduledoc """
  Parses dependency manifests and produces Wardley map nodes and edges.

  Supported manifest types:
    - Elixir: mix.exs + mix.lock
    - JavaScript/Node: package.json
    - Ruby: Gemfile + Gemfile.lock

  Each dependency becomes a node positioned by:
    - y_pct (visibility): abstraction layer — application sits high, runtime sits low
    - x_pct (evolution): heuristic based on package version maturity

  Unknown packages float to y=50 (mid-map) until manually categorized.
  Nodes within the same layer are x-jittered to reduce overlap.
  """

  @doc """
  Parse a project directory and return %{nodes: [...], edges: [...]} ready for
  insertion via Maps.create_node/1 and Maps.create_edge/1.

  Detects manifest type automatically. Raises if no known manifest found.
  """
  def parse(project_path) do
    cond do
      File.exists?(Path.join(project_path, "mix.exs")) ->
        parse_elixir(project_path)

      File.exists?(Path.join(project_path, "package.json")) ->
        parse_npm(project_path)

      File.exists?(Path.join(project_path, "Gemfile")) ->
        parse_ruby(project_path)

      true ->
        raise "No supported manifest found in #{project_path} (mix.exs, package.json, or Gemfile)"
    end
  end

  # ── Elixir ────────────────────────────────────────────────────────────────

  defp parse_elixir(path) do
    direct_deps = parse_mix_exs(Path.join(path, "mix.exs"))
    lock_data = parse_mix_lock(Path.join(path, "mix.lock"))
    nodes = build_elixir_nodes(direct_deps, lock_data)
    edges = build_elixir_edges(direct_deps, lock_data)
    %{nodes: jitter_x(nodes), edges: edges}
  end

  defp parse_mix_exs(path) do
    content = File.read!(path)

    case Regex.run(~r/defp deps do\s*\[(.*?)\]\s*end/s, content) do
      [_, deps_block] ->
        Regex.scan(~r/\{:(\w+),/, deps_block)
        |> Enum.map(fn [_, name] -> String.to_atom(name) end)

      _ ->
        []
    end
  end

  defp parse_mix_lock(path) do
    content = File.read!(path)
    {lock_map, _} = Code.eval_string(content)

    Enum.into(lock_map, %{}, fn {name, spec} ->
      {name, extract_lock_info(name, spec)}
    end)
  end

  defp extract_lock_info(name, spec) do
    case spec do
      {:hex, _pkg, version, _hash, _build, sub_deps, _repo, _hash2} ->
        %{name: name, version: version, source: :hex, deps: extract_dep_names(sub_deps)}

      {:hex, _pkg, version, _hash, _build, sub_deps, _repo} ->
        %{name: name, version: version, source: :hex, deps: extract_dep_names(sub_deps)}

      {:git, url, _hash, _opts} ->
        %{name: name, version: "git", source: :git, url: url, deps: []}

      _ ->
        %{name: name, version: "unknown", source: :unknown, deps: []}
    end
  end

  defp extract_dep_names(sub_deps) when is_list(sub_deps) do
    Enum.map(sub_deps, fn {dep_name, _ver, _opts} -> dep_name end)
  end

  defp extract_dep_names(_), do: []

  defp build_elixir_nodes(direct_deps, lock_data) do
    root = %{
      text: "app",
      x_pct: 50.0,
      y_pct: 95.0,
      metadata: %{layer: "application", direct: true, root: true, ecosystem: "elixir"}
    }

    dep_nodes =
      Enum.map(lock_data, fn {name, info} ->
        layer = classify_elixir(name)
        y = layer_to_y(layer)
        x = evolution_x(info.version)

        %{
          text: to_string(name),
          x_pct: x,
          y_pct: y,
          metadata: %{
            layer: layer,
            version: info.version,
            source: to_string(info.source),
            direct: name in direct_deps,
            ecosystem: "elixir"
          }
        }
      end)

    [root | dep_nodes]
  end

  defp build_elixir_edges(direct_deps, lock_data) do
    root_edges =
      Enum.map(direct_deps, fn dep ->
        %{source_label: "app", target_label: to_string(dep)}
      end)

    transitive_edges =
      Enum.flat_map(lock_data, fn {name, info} ->
        Enum.map(info.deps, fn dep_name ->
          %{source_label: to_string(name), target_label: to_string(dep_name)}
        end)
      end)

    root_edges ++ transitive_edges
  end

  # ── npm / package.json ────────────────────────────────────────────────────

  defp parse_npm(path) do
    pkg = path |> Path.join("package.json") |> File.read!() |> Jason.decode!()
    name = pkg["name"] || "app"

    direct_deps =
      Map.merge(pkg["dependencies"] || %{}, pkg["devDependencies"] || %{})
      |> Map.keys()

    dev_deps = Map.keys(pkg["devDependencies"] || %{})

    # Load lock for transitive deps if available
    lock_edges =
      case parse_package_lock(Path.join(path, "package-lock.json")) do
        {:ok, edges} -> edges
        :skip -> []
      end

    root = %{
      text: name,
      x_pct: 50.0,
      y_pct: 95.0,
      metadata: %{layer: "application", direct: true, root: true, ecosystem: "npm"}
    }

    dep_nodes =
      Enum.map(direct_deps, fn dep_name ->
        version =
          (pkg["dependencies"] || %{})[dep_name] || (pkg["devDependencies"] || %{})[dep_name] ||
            "unknown"

        layer = classify_npm(dep_name)
        y = layer_to_y(layer)
        x = evolution_x_semver(version)

        %{
          text: dep_name,
          x_pct: x,
          y_pct: y,
          metadata: %{
            layer: layer,
            version: version,
            direct: true,
            dev: dep_name in dev_deps,
            ecosystem: "npm"
          }
        }
      end)

    root_edges =
      Enum.map(direct_deps, fn dep ->
        %{source_label: name, target_label: dep}
      end)

    %{nodes: jitter_x([root | dep_nodes]), edges: root_edges ++ lock_edges}
  end

  defp parse_package_lock(path) do
    case File.read(path) do
      {:ok, content} ->
        lock = Jason.decode!(content)
        deps = lock["packages"] || lock["dependencies"] || %{}

        edges =
          deps
          |> Enum.flat_map(fn {pkg_path, info} ->
            pkg_name = pkg_path |> String.replace(~r|^node_modules/|, "")
            sub = (info["dependencies"] || info["requires"] || %{}) |> Map.keys()
            Enum.map(sub, fn dep -> %{source_label: pkg_name, target_label: dep} end)
          end)

        {:ok, edges}

      {:error, _} ->
        :skip
    end
  end

  # ── Ruby / Gemfile ────────────────────────────────────────────────────────

  defp parse_ruby(path) do
    gemfile = Path.join(path, "Gemfile")
    direct_gems = parse_gemfile(gemfile)

    {lock_gems, lock_edges} =
      case parse_gemfile_lock(Path.join(path, "Gemfile.lock")) do
        {:ok, data} -> data
        :skip -> {%{}, []}
      end

    root = %{
      text: "app",
      x_pct: 50.0,
      y_pct: 95.0,
      metadata: %{layer: "application", direct: true, root: true, ecosystem: "ruby"}
    }

    all_gem_names =
      (Map.keys(lock_gems) ++ direct_gems) |> Enum.uniq()

    dep_nodes =
      Enum.map(all_gem_names, fn gem_name ->
        version = Map.get(lock_gems, gem_name, "unknown")
        layer = classify_ruby(gem_name)
        y = layer_to_y(layer)
        x = evolution_x(version)

        %{
          text: gem_name,
          x_pct: x,
          y_pct: y,
          metadata: %{
            layer: layer,
            version: version,
            direct: gem_name in direct_gems,
            ecosystem: "ruby"
          }
        }
      end)

    root_edges =
      Enum.map(direct_gems, fn gem ->
        %{source_label: "app", target_label: gem}
      end)

    %{nodes: jitter_x([root | dep_nodes]), edges: root_edges ++ lock_edges}
  end

  defp parse_gemfile(path) do
    content = File.read!(path)

    Regex.scan(~r/^\s*gem\s+['"]([^'"]+)['"]/m, content)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
  end

  defp parse_gemfile_lock(path) do
    case File.read(path) do
      {:ok, content} ->
        # Parse GEM specs section for versions
        gem_versions =
          Regex.scan(~r/^    (\S+) \(([^)]+)\)/m, content)
          |> Enum.into(%{}, fn [_, name, version] -> {name, version} end)

        # Parse DEPENDENCIES section for transitive edges
        dep_edges =
          Regex.scan(~r/^    (\S+)(?: .+)?$/m, content)
          |> Enum.map(fn [_, name] -> name end)
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.flat_map(fn [a, b] ->
            if Map.has_key?(gem_versions, a) && Map.has_key?(gem_versions, b) do
              [%{source_label: a, target_label: b}]
            else
              []
            end
          end)

        {:ok, {gem_versions, dep_edges}}

      {:error, _} ->
        :skip
    end
  end

  # ── Layer classification ───────────────────────────────────────────────────
  #
  # Each classify_* function maps ecosystem-specific package names to canonical
  # layer ids defined in LayerSchema. Add packages here; never hardcode layer
  # strings anywhere else. If a package is not listed, it gets "unknown".

  alias Wardley.StackMap.LayerSchema

  # Elixir / Hex packages
  @elixir_layers %{
    # experience — none yet (user-facing product is the app itself)

    # application — full-stack frameworks and mailers
    application: ~w(phoenix phoenix_live_view phoenix_live_dashboard swoosh)a,

    # platform — web servers, plug pipeline, pubsub, clustering, asset pipeline,
    #            auth, observability services (telemetry is a platform service)
    platform: ~w(
      plug plug_crypto bandit thousand_island websock websock_adapter
      phoenix_pubsub dns_cluster
      telemetry telemetry_metrics telemetry_poller
      esbuild tailwind heroicons phoenix_live_reload
      phoenix_html phoenix_template
    )a,

    # persistence — data access, ORMs, drivers
    persistence: ~w(phoenix_ecto ecto ecto_sql postgrex db_connection decimal)a,

    # transport — HTTP clients, serialisation, codecs, i18n
    transport: ~w(req finch mint jason mime gettext expo)a,

    # runtime — low-level protocol primitives, pool/option libs, C bindings, build helpers
    runtime: ~w(
      hpax nimble_options nimble_pool idna unicode_util_compat
      file_system lazy_html cc_precompiler elixir_make fine
    )a,

    # os / firmware / silicon — not typically in mix.exs; reserved for future system-level parsing
    os: [],
    firmware: [],
    silicon: []
  }

  # npm / package.json packages
  @npm_layers %{
    experience: ~w(react react-dom vue svelte @angular/core next nuxt gatsby),
    application: ~w(express fastify koa hapi @nestjs/core),
    platform: ~w(
      body-parser cors helmet morgan compression
      passport jsonwebtoken bcryptjs
      bull bullmq agenda
      nodemailer @sendgrid/mail
      winston pino bunyan debug sentry @sentry/node newrelic
      socket.io
    ),
    persistence: ~w(mongoose sequelize typeorm prisma knex
                    pg mysql2 sqlite3 redis ioredis),
    transport: ~w(
      axios got node-fetch superagent ky undici
      ws socket.io-client
      lodash ramda underscore date-fns moment dayjs
      uuid nanoid chalk yargs commander dotenv zod joi yup
    ),
    runtime: ~w(
      webpack rollup vite parcel esbuild swc
      babel @babel/core typescript ts-node
      eslint prettier husky lint-staged
      jest mocha chai vitest jasmine karma
      @testing-library/react cypress playwright
      d3 three chart.js echarts recharts victory @visx/visx
      tailwindcss postcss autoprefixer sass less
      @tailwindcss/forms @tailwindcss/typography
      styled-components emotion @emotion/react
    ),
    os: [],
    firmware: [],
    silicon: []
  }

  # Ruby / Gemfile packages
  @ruby_layers %{
    experience: ~w(
      turbo-rails stimulus-rails hotwire-rails
      importmap-rails
    ),
    application: ~w(
      rails sinatra hanami grape roda padrino
      actionmailer actionpack actionview activesupport activejob activestorage
    ),
    platform: ~w(
      rack puma thin unicorn falcon passenger
      rack-cors rack-attack rack-mini-profiler
      sidekiq resque delayed_job
      devise omniauth cancancan pundit bcrypt jwt doorkeeper
      newrelic_rpm ddtrace skylight scout_apm lograge
      semantic_logger rails_semantic_logger
      webpacker sprockets sassc uglifier
    ),
    persistence: ~w(
      activerecord sequel rom datamapper
      pg mysql2 sqlite3 mongoid redis hiredis connection_pool
    ),
    transport: ~w(
      faraday httparty rest-client typhoeus excon mechanize
      oj multi_json json nokogiri mini_xml
      jbuilder rabl active_model_serializers i18n gettext
    ),
    runtime: ~w(
      bundler rake rubygems bootsnap spring
      rspec minitest test-unit rspec-rails capybara
      factory_bot factory_bot_rails faker shoulda-matchers webmock vcr
      tailwindcss-rails jsbundling-rails cssbundling-rails
      sass coffee-script
    ),
    os: [],
    firmware: [],
    silicon: []
  }

  # Build inverted lookup maps at compile time: package_name => layer_id
  defp do_build_lookup(layers_map) do
    Enum.flat_map(layers_map, fn {layer_id, packages} ->
      Enum.map(packages, fn pkg -> {pkg, to_string(layer_id)} end)
    end)
    |> Map.new()
  end

  defp classify_elixir(name) do
    lookup = do_build_lookup(@elixir_layers)
    Map.get(lookup, name, Map.get(lookup, to_string(name), "unknown"))
  end

  defp classify_npm(name) do
    Map.get(do_build_lookup(@npm_layers), name, "unknown")
  end

  defp classify_ruby(name) do
    Map.get(do_build_lookup(@ruby_layers), name, "unknown")
  end

  # ── Positioning helpers ────────────────────────────────────────────────────

  # y_pct derived from the canonical schema — single source of truth
  defp layer_to_y(layer_id) do
    LayerSchema.y_to_pct(LayerSchema.y_mid(layer_id))
  end

  # Jitter x within each layer so nodes don't stack on the same column.
  # Groups by (layer, y_pct), then spaces them evenly across 15–85 within that band.
  defp jitter_x(nodes) do
    groups =
      nodes
      |> Enum.reject(& &1.metadata[:root])
      |> Enum.group_by(& &1.y_pct)

    jitter_map =
      Enum.flat_map(groups, fn {_y, group} ->
        count = length(group)

        group
        |> Enum.sort_by(& &1.x_pct)
        |> Enum.with_index()
        |> Enum.map(fn {node, i} ->
          x =
            if count == 1 do
              50.0
            else
              15.0 + i * (70.0 / (count - 1))
            end

          {node.text, x}
        end)
      end)
      |> Enum.into(%{})

    Enum.map(nodes, fn node ->
      if node.metadata[:root] do
        node
      else
        Map.put(node, :x_pct, Map.get(jitter_map, node.text, node.x_pct))
      end
    end)
  end

  # Evolution x_pct from version string — higher/more stable versions sit right.
  defp evolution_x("git"), do: 15.0
  defp evolution_x("unknown"), do: 30.0
  defp evolution_x(version), do: evolution_x_semver(version)

  defp evolution_x_semver(version) do
    # Strip range operators (~>, ^, >=, ~, etc.)
    clean = Regex.replace(~r/[~^><=* ]/, version, "") |> String.trim_leading("v")

    case Version.parse(normalize_version(clean)) do
      {:ok, v} ->
        cond do
          v.major == 0 -> 15.0 + v.minor * 4.0
          v.major == 1 -> 45.0 + min(v.minor * 2.0, 20.0)
          v.major >= 2 -> 68.0 + min((v.major - 2) * 4.0, 17.0)
        end

      :error ->
        40.0
    end
  end

  defp normalize_version(v) do
    parts = String.split(v, ".")

    case length(parts) do
      1 -> v <> ".0.0"
      2 -> v <> ".0"
      _ -> v
    end
  end
end
