<%= @parent %>

WORKDIR /work
RUN mkdir /work/elixir && cd /work/elixir && \
    wget https://github.com/elixir-lang/elixir/releases/download/v1.11.4/Precompiled.zip && \
    unzip Precompiled.zip && \
    ln -s /work/elixir/bin/* /usr/local/bin/

RUN apt install -y erlang 

WORKDIR /work
RUN mix local.hex --force && mix local.rebar

ENV ERLANG_PATH /work/otp/release/<%= @arch.pc %>-linux-<%= @arch.android_name %>/erts-12.0/include
ENV ERTS_INCLUDE_DIR /work/otp/release/<%= @arch.pc %>-linux-<%= @arch.android_name %>/erts-12.0/include
ENV HOST <%= @arch.cpu %>
ENV CROSSCOMPILE Android

RUN git clone     <%= @repo %>
WORKDIR /work/<%= @basename %>
<%= if @tag do %> 
RUN git checkout @tag
<% end %>

# Three variants of building {:mix, :make, :rebar3}
ENV MIX_ENV prod
COPY build_nif.sh package_nif.sh /work/<%= @basename %>/
RUN ./build_nif.sh
