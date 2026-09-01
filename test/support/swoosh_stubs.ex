defmodule Swoosh.Email do
  @moduledoc false

  # Mirrors the real Swoosh.Email surface the mutators match: same exported names and arities
  # (bare-import resolution reads them), and the same option handling in new/1 — including the
  # ArgumentError on an unknown key, so a mutant minting an invalid option would fail loudly.

  defstruct subject: "",
            from: nil,
            to: [],
            cc: [],
            bcc: [],
            text_body: nil,
            html_body: nil,
            reply_to: nil,
            attachments: [],
            headers: %{},
            assigns: %{},
            provider_options: %{}

  @new_apply_fields ~w(subject from to cc bcc reply_to text_body html_body attachment)a
  @new_put_fields ~w(headers assigns provider_options)a

  def new(opts \\ []) do
    Enum.reduce(opts, %__MODULE__{}, &do_new/2)
  end

  defp do_new({key, value}, email) when key in @new_apply_fields,
    do: apply(__MODULE__, key, [email, value])

  defp do_new({key, value}, email) when key in @new_put_fields,
    do: Map.put(email, key, value)

  defp do_new({key, value}, _email) do
    raise ArgumentError,
          "invalid field `#{inspect(key)}` (value=#{inspect(value)}) for Swoosh.Email.new/1"
  end

  def from(%__MODULE__{} = email, from), do: %{email | from: from}
  def reply_to(%__MODULE__{} = email, reply_to), do: %{email | reply_to: reply_to}
  def subject(%__MODULE__{} = email, subject), do: %{email | subject: subject}
  def text_body(%__MODULE__{} = email, body), do: %{email | text_body: body}
  def html_body(%__MODULE__{} = email, body), do: %{email | html_body: body}

  def to(%__MODULE__{} = email, recipients), do: %{email | to: List.wrap(recipients) ++ email.to}
  def cc(%__MODULE__{} = email, recipients), do: %{email | cc: List.wrap(recipients) ++ email.cc}

  def bcc(%__MODULE__{} = email, recipients),
    do: %{email | bcc: List.wrap(recipients) ++ email.bcc}

  def put_to(%__MODULE__{} = email, recipients), do: %{email | to: List.wrap(recipients)}
  def put_cc(%__MODULE__{} = email, recipients), do: %{email | cc: List.wrap(recipients)}
  def put_bcc(%__MODULE__{} = email, recipients), do: %{email | bcc: List.wrap(recipients)}

  def attachment(%__MODULE__{} = email, attachment),
    do: %{email | attachments: [attachment | email.attachments]}

  def header(%__MODULE__{} = email, name, value) when is_binary(name) and is_binary(value),
    do: %{email | headers: Map.put(email.headers, name, value)}

  def put_provider_option(%__MODULE__{} = email, key, value) when is_atom(key),
    do: %{email | provider_options: Map.put(email.provider_options, key, value)}
end

defmodule Swoosh.Attachment do
  @moduledoc false

  defstruct path: nil,
            data: nil,
            filename: nil,
            content_type: nil,
            type: :attachment,
            cid: nil,
            headers: []

  def new(path, opts \\ [])

  def new({:data, data}, opts), do: struct!(__MODULE__, opts |> Map.new() |> Map.put(:data, data))
  def new(path, opts), do: struct!(__MODULE__, opts |> Map.new() |> Map.put(:path, path))
end

defmodule Mutare.SwooshTest.Mailer do
  @moduledoc false

  # A stand-in for an application mailer (`use Swoosh.Mailer` defines these), so Deliver tests
  # can exercise the imported-call form; qualified and aliased matching is purely syntactic.

  def deliver(email, config \\ []), do: {:ok, %{email: email, config: config}}
  def deliver!(email, config \\ []), do: %{email: email, config: config}
end
