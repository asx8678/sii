# Si

Si is a control plane for coding agents, written in Elixir/OTP (Phoenix and LiveView). Pi sessions with the Fabric extension do the coding. Si decides what they work on, checks what they produce, has Astra review it on a model from a different family, and lands it. This repository builds Si from the plan in `final_plan/`: 126 tasks, each with exact deliverables, tests, acceptance criteria and verification commands. Start with `final_plan/README.md`.

## Rules for all work in this repository

These apply to anyone who writes or reviews code here, including the sessions Si itself starts.

1. **Build the plan, not a new design.** Each change implements one task file in `final_plan/tasks/`: its Deliverables and Specification, nothing more. Add dependencies only when the task lists them.
2. **Skipped topics are off limits** (`final_plan/00-overview.md`, "Skipped"): self-healing and dev mode for Si itself, worker isolation profiles, command policy, prompt-injection handling, a data egress policy, dependency and secret checks, and keeping workers alive or reattaching them across Si restarts. Don't implement them or substitutes for them.
3. **The builder approval policy is the owner's decision** (`profiles.builder.approvals`, chosen with `si init` in T05.11). Code never picks a value for it, and builders don't start while it is unset.
4. **Tests never call real models.** They use the scripted `si-faux` provider, and every Pi process a test starts has `PI_OFFLINE=1`.
5. **No secrets** in the repository, in logs or in command output. Token files are created with mode 0600.
6. **Code rules** (`final_plan/02-repo-layout.md` §2): contexts expose functions; modules have `@moduledoc`, and public functions have `@doc` and `@spec`; structs at boundaries. New code has tests.
7. **`main` stays green.** Every commit that reaches `main` passes `bin/ci`: format, compile with warnings as errors, credo strict, tests (warnings as errors), and TypeScript lint, typecheck and tests once `bridge/`, `testing/pi-faux/` or `adapter/` exist. Before T00.02 creates `bin/ci`, the task's Verify commands are the gate. The Phoenix guidelines below say to run `mix precommit`; here `bin/ci` is the check that counts.
8. **Keep the docs true.** A new event type, settings key or table goes into `final_plan/03-data-model.md` or `05-schemas-and-config.md` in the same change.
9. **Reference sources are read-only.** `/Users/adam2/projects/pair/` holds Pi 0.87.1 (`pi/`), Fabric 0.97.0 (`pi-fabric/`), Fovea 0.31.1 (`pi-fovea/`), Pair (`pi-fabric-pair/`) and the owner's audit of Pair (`todo1/`).

## Implementation agent

This section is for the coding agent the owner runs in this folder to build Si, for example Pi started here with `pi`. Sessions that Si starts (Astra, builders, critics and the rest) follow their role prompt instead; for them this section is only background. The long form of this procedure, with the completion-note template, is `final_plan/AGENT_PROMPT.md`; both say the same thing.

### At the start of every session

1. `git config user.name` and `git config user.email` must both print a value. If either is empty, stop and ask the owner. Never invent an identity.
2. If T00.01 is not done yet (there is no `mix.exs`), check the environment: Elixir 1.20 on Erlang/OTP 29, `mix phx.new --version` 1.8.x, Node 24 or newer with npm, git, a C compiler (`cc --version`; on macOS the Xcode Command Line Tools, which MuonTrap needs), and network access to hex.pm and the npm registry. If something is missing, report exactly what and stop; otherwise the next task is T00.01.
3. Finish interrupted work first: a `task/*` branch not merged into `main` (`git branch --list 'task/*' --no-merged main`), or a task marked `in_progress` in `final_plan/tasks.yaml`.

### Choosing a task

- Take the first task in `final_plan/tasks.yaml`, in file order, whose `status` is `todo` and whose `depends_on` tasks are all `done`.
- **Astra first:** while any task with `astra_path: true` is not `done`, take only those. Right after them, take T05.11.
- Do one task per request unless the owner asks for more. If the owner runs several agents at once, follow "Parallel agents" in `final_plan/AGENT_PROMPT.md`.

### Doing a task

1. Start from a clean, current `main` (`git checkout main && git pull --ff-only`), then create the branch named in the task file's header: `git checkout -b task/<ID>-<slug>`. Set the task's status to `in_progress` in `tasks.yaml` on that branch.
2. Read the whole task file, the documents it names and the code it builds on. When it says to check something in the Pi, Fabric or Fovea source, check it before you rely on it.
3. Implement exactly the Deliverables and Specification. Write the listed tests, first where practical. Commit messages start with `<ID>: `.
4. Check the work with the loop in "After writing each task" below, until every check shows its expected result.
5. Write the completion note `final_plan/status/<ID>.md` (template: `final_plan/10-after-each-task.md` §8) and set the task's status to `done` in `tasks.yaml`, in one commit. Then run `bin/task-check --final`. Expected: `RESULT: PASS`.
6. From T05.10 on, run `bin/task-review` (Astra, on the review node). On `REVISE`, treat each blocking finding as a failed check. Fix it with the loop below, commit, and run the review again. After 5 rounds without `APPROVE`, stop and ask the owner. Change nothing after the final approval.
7. Merge. If `main` moved, rebase and repeat from step 4 (and, from T05.10 on, step 6). Then run `git checkout main && git merge --ff-only task/<ID>-<slug>`, followed by `bin/ci` on `main` (expected: `PASS`). From T05.10 on, also run `bin/review-node update`. When the task completes a milestone, run its checkpoint (`10-after-each-task.md` §10).
8. Report to the owner in a few lines:
   - the task and what changed;
   - the results of `bin/task-check`, the Verify commands and the After implementing checks;
   - any redo, and why;
   - the review verdict (from T05.10 on);
   - any follow-ups;
   - the next task, with its size. If that task is size L, suggest planning it first: `/thinking max`, then `/si-plan <ID>`.

If a task is wrong, contradicts another document or can't be done as written: set it to `blocked`, explain why in its completion note with evidence (commands, output, file and line), propose a concrete change to the plan, and stop. Don't silently change the design.

### After writing each task

Work is finished only when every check shows exactly its expected result. The full rules are in `final_plan/10-after-each-task.md`. Do these in order:

1. Commit the work, then run `bin/task-check`. Expected: `RESULT: PASS`. Fix every `WARN`, or explain it in the note. (T00.01 comes before `bin/task-check` exists, so do its gates by hand as its task file says.)
2. Run every command in the task's **Verify** section. Run a multi-line block as one shell command. Expected: the result written next to each command; where none is written, exit 0 with no error output.
3. Run every check in the task's **After implementing** section. Expected: the result stated for each one.
4. For each acceptance criterion, name the test (file and name) or the command output that proves it. A criterion without evidence is not met.
5. Read `git diff main...HEAD` against the Specification (checklist: `10-after-each-task.md` §6). Then break the code on purpose once (flip a condition a test should guard), confirm that a test fails, and restore it.

Any other result means the task goes back:
- A slip or a defect: fix the code, and add a test if none caught it. Never change what a test expects, never skip or weaken a test, never raise a timeout or add a sleep, never silence an error or a warning.
- A wrong approach, or the same check failing again after two fixes: rewrite that part from the Specification. The task's **Redo if** list names the typical cases.
- If the rewritten part fails the same check: redo the whole task once from a fresh branch (`10-after-each-task.md` §5).
- If that fails too: set the task to `blocked` and ask the owner.

After every change, run the loop again from step 1. Record what you saw, not what you expected to see, and every redo, in the completion note.

### Running commands

- The bash tool has no default timeout. Give commands that can hang one: about 900 s for dependency installs, builds and full test runs, and 60 s for single checks.
- Start servers in the background with their output in a log file under `tmp/` (git ignores it), and print the PID: `mkdir -p tmp; bin/si-server > tmp/si-server.log 2>&1 & echo $!`. Stop exactly that PID when you are done (`kill <pid>`). Never use `pkill`, `killall` or name patterns, because other projects on this machine run their own Phoenix servers and BEAM nodes. Before starting a server, check that its port is free, for example `lsof -nP -iTCP:4040 -sTCP:LISTEN`.
- The repository's remote is `origin` (`git@github.com:asx8678/si.git`). Pull with `--ff-only`. Push only when the owner asks, and never force-push.
- Don't pipe `mix` or `elixir` output into `head`: closing the pipe early makes the VM crash and write an `erl_crash.dump`. Redirect to a file under `tmp/` and read that instead.
- Run nothing interactive: no `iex`, no editors, no `git rebase -i`, no `git add -p`. Pipe `yes` into generators that prompt, pass `-m` to `git commit`, and use `GIT_EDITOR=true git rebase --continue`.
- Change files only in this folder, in the Si homes (`~/.si`, plus `~/.si-review` for the review node from T05.10 on), in temporary directories that tests create, and, for parallel agents, in their worktrees under `/Users/adam2/projects/skynet-work/`.

### Stop and ask the owner when

- a task is blocked, or Astra hasn't approved after 5 rounds;
- a decision belongs to the owner: the builder approval policy, which models Si uses (Astra on the review node must run on a model from a different family than yours), or which repositories to use for evals;
- a step calls real models or costs money, such as the manual check in T05.10, `si init --check-models` or eval runs in T07.04. Ask first, then record the output in the completion note;
- a step would change something on the owner's machine outside the project and the Si homes: `si bridge install --apply` (T04.12), `bin/si-install` (T11.12), pushing to a real remote, or opening a real pull request. Tests use fakes for all of these;
- credentials, network access or tool installation fail in a way you can't fix inside the repository.

# Phoenix guidelines (generated by phx.new 1.8.13)

This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied
<!-- phoenix:ecto-end -->

<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
<!-- phoenix:liveview-end -->

<!-- usage-rules-end -->