<%= @parent %>

WORKDIR /work
RUN mkdir /work/elixir && cd /work/elixir && \
    wget https://github.com/elixir-lang/elixir/releases/download/v1.11.4/Precompiled.zip && \
    unzip Precompiled.zip && \
    ln -s /work/elixir/bin/* /usr/local/bin/

RUN apt install -y erlang 

WORKDIR /work
RUN mix local.hex --force && mix local.rebar

RUN git clone <%= @repo %>
WORKDIR /work/<%= @basename %>
<%= if @tag do %> 
RUN git checkout @tag
<% end %>

<%= if @tool == :mix do %>
ENV MIX_ENV prod
RUN mix deps.get && mix release
<% else %>
RUN /root/.mix/rebar3 compile
<% end %>
