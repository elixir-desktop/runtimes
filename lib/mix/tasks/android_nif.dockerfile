<%= @parent %>

WORKDIR /work
RUN mkdir /work/elixir && cd /work/elixir && \
    wget https://github.com/elixir-lang/elixir/releases/download/v1.11.4/Precompiled.zip && \
    unzip Precompiled.zip && \
    ln -s /work/elixir/bin/* /usr/local/bin/

RUN apt install -y erlang 

WORKDIR /work
RUN mix local.hex --force && mix local.rebar

ENV ERLANG_PATH /work/otp/release/<%= @arch.pc %>-linux-<%= @arch.android_name %>/erts-<%= @erts_version %>/include
ENV ERTS_INCLUDE_DIR /work/otp/release/<%= @arch.pc %>-linux-<%= @arch.android_name %>/erts-<%= @erts_version %>/include
ENV HOST <%= @arch.cpu %>
ENV CROSSCOMPILE Android
ENV CC=clang CXX=clang++

RUN git clone <%= @repo %>
WORKDIR /work/<%= @basename %>
<%= if @tag do %> 
RUN git checkout <%= @tag %>
<% end %>

# Three variants of building {:mix, :make, :rebar3}
ENV MIX_ENV prod
COPY scripts/build_nif.sh scripts/package_nif.sh /work/<%= @basename %>/
RUN ./build_nif.sh
