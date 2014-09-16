import Onion
import Onion.RPC

deftable TestModel, pk: [:id] do
    deffield :id,    type: :int, autoincrement: true, null: false
    deffield :name,  type: :string,  null: false, default: "undefined"
    deffield :type,  type: :int, null: false, default: 1
end

deftable TestModel2, pk: [:id, :name] do
    deffield :id,    type: :int, autoincrement: true, null: false
    deffield :name,  type: :string,  null: false, default: "undefined"
    deffield :type,  type: :int, null: false, default: 1
end

defmiddleware Out do
    def process(:in, state, opts) do
        reply state, 200, state[:request][:args]
    end
end



defhandler Route2, middlewares: [
        Onion.Common.BaseHttpData, 
        Onion.Common.HttpPostData, 
        #Onion.Common.DumbFlashResponse,
    ] do
    
    route "/table/[:id]", middlewares: [
        Onion.Common.ValidateArgs.init(optional: TestModel.fields, strict: true), 
        Onion.RPC.Resource.init(model: TestModel)
    ]

    route "/table2/[:id/:name]", middlewares: [
        Onion.Common.ValidateArgs.init(optional: TestModel2.fields, strict: true), 
        Onion.RPC.Resource.init(model: TestModel2)
    ]
end


defserver Server2, port: 8081 do
    handler Route2
end


defmodule Onion.Common.Application do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Onion.Worker, [arg1, arg2, arg3])
    ]

    Server2.start

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Onion.Supervisor2]
    Supervisor.start_link(children, opts)
  end
end
