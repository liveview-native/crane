defmodule Crane.Object do
  @moduledoc false

  def struct_fields(opts, nil) do
    defaults = [
      name: nil,
      refs: %{},
      created_at: nil,
      assigns: %{},
    ]

    Keyword.merge(defaults, opts)
  end

  def struct_fields(opts, {owner_key, _owner_module}) do
    opts
    |> struct_fields(nil)
    |> Keyword.merge([{String.to_atom("#{owner_key}_name"), nil}])
  end

  def key_from_module(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end

  def owner_tuple(nil),
    do: nil
  def owner_tuple({name, module}),
    do: {name, module}
  def owner_tuple(module) do
    name = key_from_module(module)

    {name, module}
  end

  def set_owner(opts, nil),
    do: opts
  def set_owner(opts, {owner_key, _owner_module}) do
    case Keyword.pop(opts, owner_key) do
      {nil, opts} -> opts
      {owner, opts} -> Keyword.put(opts, String.to_atom("#{owner_key}_name"), owner.name)
    end
  end

  defmacro __using__(opts \\ []) do
    {owner, opts} = Keyword.pop(opts, :owner)
    quote location: :keep do
      use GenServer

      @singleton unquote(opts[:name])
      @owner Crane.Object.owner_tuple(unquote(owner))

      import Crane.Object, only: [
        defchild: 1
      ]

      defstruct Crane.Object.struct_fields(unquote(opts), @owner)

      def start_link(opts) when is_list(opts) do
        opts = if @singleton do
          opts ++ [name: @singleton]
        else
          name_prefix = %__MODULE__{} |> Map.get(:name_prefix)
          Keyword.put_new(opts, :name, Crane.Utils.generate_name(
            name_prefix || Crane.Object.key_from_module(__MODULE__)))
        end

        opts = Keyword.drop(opts, [:name_prefix])

        GenServer.start_link(__MODULE__, opts, name: opts[:name])
      end

      defoverridable start_link: 1

      @impl true
      def init(opts) do
        Process.flag(:trap_exit, true)

        opts =
          opts
          |> Keyword.put(:created_at, DateTime.now!("Etc/UTC"))
          |> Crane.Object.set_owner(@owner)

        values =
          %__MODULE__{}
          |> Map.to_list()
          |> Keyword.drop([:__struct__, :refs])

        values = if @owner,
          do: List.insert_at(values, -1, @owner),
          else: values

        {opts, other_opts} = Keyword.split_with(opts, &(elem(&1, 0) in Keyword.keys(values)))

        {:ok, opts} = Keyword.validate(opts, values)

        {:ok, struct(%__MODULE__{}, opts), {:continue, {:init, other_opts}}}
      end

      defoverridable init: 1

      @impl true
      def handle_continue(_contine_arg, object),
        do: {:noreply, object}

      defoverridable handle_continue: 2

      @impl true
      def handle_call(:get, _from, object),
        do: {:reply, {:ok, object}, object}

      def handle_call({:update, opts}, _from, object) do
        object = struct(object, opts)
        {:reply, {:ok, object}, object, {:continue, {:update, opts}}}
      end

      @impl true
      def handle_info({:DOWN, ref, :process, _pid, _reason}, %__MODULE__{refs: refs} = object) when is_map_key(refs, ref) do
        {_name, refs} = Map.pop(refs, ref)

        {:noreply, %__MODULE__{object | refs: refs}}
      end

      if @singleton do
        def get,
          do: GenServer.call(@singleton, :get)

        defoverridable get: 0

        def get! do
          {:ok, object} = get()
          object
        end

        defoverridable get!: 0

        def update(opts),
          do: GenServer.call(@singleton, {:update, opts})

        defoverridable update: 1

      else
        def new(opts \\ []) when is_list(opts) do
          with {:ok, pid} <- start_link(opts),
            {:ok, object} <- GenServer.call(pid, :get) do
              {:ok, object}
          else
            error -> {:error, error}
          end
        end

        defoverridable new: 1

        def new!(opts) do
          {:ok, object} = new(opts)
          object
        end

        defoverridable new!: 1

        def get(name) when is_binary(name),
          do: get(String.to_existing_atom(name))
        def get(name) when is_atom(name),
          do: get(%__MODULE__{name: name})
        def get(%__MODULE__{name: name}),
          do: GenServer.call(name, :get)

        defoverridable get: 1

        def get!(name) when is_binary(name),
          do: get!(String.to_existing_atom(name))
        def get!(name) when is_atom(name),
          do: get(%__MODULE__{name: name})
        def get!(object) do
          {:ok, object} = get(object)
          object
        end

        defoverridable get!: 1

        def close(%__MODULE__{name: name}),
          do: GenServer.stop(name, :normal)

        defoverridable close: 1

        def update(%__MODULE__{name: name}, opts),
          do: GenServer.call(name, {:update, opts})

        defoverridable update: 2
      end
    end
  end

  defmacro defchild([{name, module}]) do
    singular_var = Macro.var(name, __CALLER__.module)
    plural_name = Inflex.pluralize(name) |> String.to_atom()
    plural_var = Macro.var(plural_name, __CALLER__.module)
    new_name = String.to_atom("new_#{name}")

    quote location: :keep do
      def handle_call({unquote(new_name), opts}, _from, %__MODULE__{refs: refs, name: name} = object) do
        args = if @singleton do
          []
        else
          [Keyword.merge(opts, [{Crane.Object.key_from_module(__MODULE__), object}])]
        end

        with {:ok, unquote(singular_var)} <- apply(unquote(module), :new, args),
          refs <- Crane.Utils.monitor(unquote(singular_var), refs) do
            object = %__MODULE__{object | refs: refs}
            Crane.Utils.broadcast(Crane, {unquote(new_name), unquote(singular_var)})

            {:reply, {:ok, unquote(singular_var), object}, object, {:continue, {unquote(new_name), opts}}}
        else
          error -> {:reply, error, object, {:continue, {unquote(new_name), error}}}
        end
      end

      def handle_call(unquote(plural_name), _from, %__MODULE__{refs: refs} = object) do
        var!(unquote({plural_name, [], Elixir})) = Crane.Utils.get_reference_object(refs, unquote(name), fn(name) ->
          unquote(module).get(name)
        end)
        |> Enum.sort_by(&(&1.created_at), {:asc, DateTime})

        {:reply, {:ok, var!(unquote(plural_var))}, object, {:continue, unquote(plural_name)}}
      end

      if @singleton do
        def unquote(new_name)(opts \\ []),
          do: GenServer.call(@singleton, {unquote(new_name), opts})

        defoverridable [{unquote(new_name), 1}]

        def unquote(String.to_atom("#{new_name}!"))(opts \\ []) do
          {:ok, object} = unquote(new_name)(opts)
          object
        end

        defoverridable [{unquote(String.to_atom("#{new_name}!")), 1}]

        def unquote(plural_name)(),
          do: GenServer.call(@singleton, unquote(plural_name))

        defoverridable [{unquote(plural_name), 0}]

        def unquote(String.to_atom("#{plural_name}!"))() do
          {:ok, objects} = unquote(plural_name)()
          objects
        end

        defoverridable [{unquote(String.to_atom("#{plural_name}!")), 0}]

        def unquote(String.to_atom("close_#{name}"))(%unquote(module){} = unquote(singular_var)) do
          :ok = unquote(module).close(unquote(singular_var))
          get()
        end

        defoverridable [{unquote(String.to_atom("close_#{name}")), 1}]

        def unquote(String.to_atom("close_#{name}!"))(unquote(singular_var)) do
          unquote(String.to_atom("close_#{name}"))(unquote(singular_var))
        end

        defoverridable [{unquote(String.to_atom("close_#{name}!")), 1}]
      else
        def unquote(new_name)(%__MODULE__{name: name}, opts \\ []),
          do: GenServer.call(name, {unquote(new_name), opts})

        defoverridable [{unquote(new_name), 2}]

        def unquote(String.to_atom("#{new_name}!"))(%__MODULE__{} = parent, opts \\ []) do
          {:ok, object} = unquote(new_name)(parent, opts)
          object
        end

        defoverridable [{unquote(String.to_atom("#{new_name}!")), 2}]

        def unquote(plural_name)(%__MODULE__{name: name}),
          do: GenServer.call(name, unquote(plural_name))

        defoverridable [{unquote(plural_name), 1}]

        def unquote(String.to_atom("#{plural_name}!"))(%__MODULE__{} = parent) do
          {:ok, objects} = unquote(plural_name)(parent)
          objects
        end

        defoverridable [{unquote(String.to_atom("#{plural_name}!")), 1}]

        def unquote(String.to_atom("close_#{name}"))(%__MODULE__{} = parent, %unquote(module){} = unquote(singular_var)) do
          :ok = unquote(module).close(unquote(singular_var))
          get(parent)
        end
        def unquote(String.to_atom("close_#{name}"))(parent_name, %unquote(module){} = unquote(singular_var)) do
          :ok = unquote(module).close(unquote(singular_var))
          get(parent_name)
        end

        defoverridable [{unquote(String.to_atom("close_#{name}")), 2}]

        def unquote(String.to_atom("close_#{name}!"))(parent_or_name, unquote(singular_var)) do
          unquote(String.to_atom("close_#{name}"))(parent_or_name, unquote(singular_var))
        end

        defoverridable [{unquote(String.to_atom("close_#{name}!")), 2}]
      end
    end
  end

end

