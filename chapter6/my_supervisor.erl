-module(my_supervisor).
-export([start_link/2, stop/1]).
-export([init/1]).

start_link(Name, ChildSpecList) ->
  register(Name, spawn_link(my_supervisor, init, [ChildSpecList])), ok.

init(ChildSpecList) ->
  process_flag(trap_exit, true),
  loop(start_children(ChildSpecList)).

start_children([]) -> [];
start_children([{M, F, A, T} | ChildSpecList]) ->
  case (catch spawn_link(M,F,A)) of
    {'EXIT', _} ->
      start_children(ChildSpecList);
    Pid ->
      [{Pid, {M, F, A, T}}|start_children(ChildSpecList)]
  end.

%% The loop of the supervisor waits in a receive clause for EXIT and stop messages.
%% If a child terminates, the supervisor receives the EXIT signal and restarts the terminated
%% child, replacing its entry in the list of children stored in the ChildList variable:

restart_child(Pid, ChildList, Reason) ->
  {value, {Pid, {M, F, A, T}}} = lists:keysearch(Pid, 1, ChildList),
  case {T, Reason} of
    {transient, normal} ->
      lists:keydelete(Pid,1,ChildList);
    _ ->
      NewPid = spawn_link(M,F,A),
      [{NewPid, {M, F, A, T}}|lists:keydelete(Pid,1,ChildList)]
  end.

loop(ChildList) ->
  receive
    {'EXIT', Pid, Reason} ->
      NewChildList = restart_child(Pid, ChildList, Reason),
      loop(NewChildList);
    {stop, From}  ->
      From ! {reply, terminate(ChildList)}
  end.

%% We stop the supervisor by calling the synchronous client function stop/0. Upon receiving the
%% stop message, the supervisor runs through the ChildList, terminating the children one by one.
%% Having terminated all the children, the atom ok is returned to the process that initiated
%% the stop call:

stop(Name) ->
  Name ! {stop, self()},
  receive {reply, Reply} -> Reply end.

terminate([{Pid, _} | ChildList]) ->
  exit(Pid, kill),
  terminate(ChildList);
terminate(_ChildList) -> ok.
