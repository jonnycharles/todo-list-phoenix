defmodule TodoListWeb.TodoLive do
  use TodoListWeb, :live_view
  alias TodoList.Todos
  alias TodoList.Todos.Todo

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TodoList.PubSub, "todos")
    end

    {:ok,
     socket
     |> assign(:todos, Todos.list_todos())
     |> assign(:form, to_form(Todos.change_todo(%Todo{})))}
  end

  @impl true
  def handle_event("validate", %{"todo" => todo_params}, socket) do
    changeset =
      %Todo{}
      |> Todos.change_todo(todo_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"todo" => todo_params}, socket) do
    case Todos.create_todo(todo_params) do
      {:ok, todo} ->
        Phoenix.PubSub.broadcast(TodoList.PubSub, "todos", {:todo_created, todo})

        {:noreply,
         socket
         |> put_flash(:info, "Todo created successfully")
         |> assign(:form, to_form(Todos.change_todo(%Todo{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_done", %{"id" => id}, socket) do
    todo = Todos.get_todo!(id)
    {:ok, updated_todo} = Todos.update_todo(todo, %{done: !todo.done})
    Phoenix.PubSub.broadcast(TodoList.PubSub, "todos", {:todo_updated, updated_todo})
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    todo = Todos.get_todo!(id)
    {:ok, _} = Todos.delete_todo(todo)
    Phoenix.PubSub.broadcast(TodoList.PubSub, "todos", {:todo_deleted, todo})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:todo_created, todo}, socket) do
    {:noreply, update(socket, :todos, &[todo | &1])}
  end

  @impl true
  def handle_info({:todo_updated, updated_todo}, socket) do
    {:noreply, update(socket, :todos, fn todos ->
      Enum.map(todos, fn todo ->
        if todo.id == updated_todo.id, do: updated_todo, else: todo
      end)
    end)}
  end

  @impl true
  def handle_info({:todo_deleted, deleted_todo}, socket) do
    {:noreply, update(socket, :todos, fn todos ->
      Enum.reject(todos, &(&1.id == deleted_todo.id))
    end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">Todo List</h1>

      <.form for={@form} phx-change="validate" phx-submit="save" class="mb-8">
        <div class="flex gap-4">
          <div class="flex-1">
            <.input
              field={@form[:title]}
              type="text"
              placeholder="Enter a new todo"
              class="w-full p-2 border rounded"
            />
          </div>
          <.button
            type="submit"
            class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            disabled={!@form.source.valid?}
          >
            Add Todo
          </.button>
        </div>
      </.form>

      <div class="space-y-4">
        <%= for todo <- @todos do %>
          <div class="flex items-center justify-between p-4 bg-white rounded shadow">
            <div class="flex items-center gap-4">
              <input
                type="checkbox"
                checked={todo.done}
                phx-click="toggle_done"
                phx-value-id={todo.id}
                class="h-5 w-5"
              />
              <span class={["text-gray-900", todo.done && "line-through text-gray-500"]}>
                <%= todo.title %>
              </span>
            </div>
            <.button
              phx-click="delete"
              phx-value-id={todo.id}
              class="text-red-500 hover:text-red-700"
            >
              Delete
            </.button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
