% This line consults the knowledge bases from this file,
% instead of needing to consult the files individually.
% This line MUST be included in the final submission.
:- ['transport_kb', 'slots_kb'].
scheduled_week_day_for_group(Week, Day, Group) :-
	scheduled_slot(Week, Day, _, _, Group).
	group_days(Group, Day_Timings):-
		findall(day_timing(Week, Day), scheduled_week_day_for_group(Week, Day, Group),DayList1),
		reverse(DayList1,DayList2),
		filter(DayList2,DayList3),
		reverse(DayList3,Day_Timings).
filter([],[]).
filter([H|T],[H|T2]):-
	\+member(H,T),
	filter(T,T2).    

 filter([H|T],Res):-  
	member(H,T),
filter(T,Res).

%Gets the slots for a certain group on a certain day and week.
day_slots(Group, Week, Day, Slots):-
	findall(X, 
		(
			slot(X, _, _), 
			scheduled_slot(Week, Day, X, _, Group)), Slots).

%Gets the earlies slot of the day.
earliest_slot(Group, Week, Day, Slot):-
	day_slots(Group, Week, Day, Slots), 
	min_list(Slots, Slot). 



%Proper Connection
proper_connection(Station_A, Station_B, Duration, Line):-
	connection(Station_A, Station_B, Duration, Line).
proper_connection(Station_A, Station_B, Duration, Line):-
	 \+ unidirectional(Line), 
	connection(Station_B, Station_A, Duration, Line).

 %AppendConnection 
append_connection(Conn_Source, Conn_Destination, Conn_Duration, Conn_Line, [], [route(Conn_Line,Conn_Source,Conn_Destination,Conn_Duration)]).
append_connection(Conn_Source, Conn_Destination, Conn_Duration, Conn_Line, Routes_So_Far, Routes):-
	Routes_So_Far \= [], 
	last(Routes_So_Far, 
		route(Line, _, _, _)), Line \= Conn_Line, 
	append(Routes_So_Far, 
		[route(Conn_Line, Conn_Source, Conn_Destination, Conn_Duration)], Routes).
append_connection(_, Conn_Destination, Conn_Duration, Conn_Line, Routes_So_Far, Routes):-
	Routes_So_Far \= [], 
	last(Routes_So_Far, 
		route(Conn_Line, Start, End, Time)), Start \= Conn_Destination, TotalDuration is Time + Conn_Duration, 
	delete(Routes_So_Far, 
		route(Conn_Line, Start, End, Time), Resultant), 
	append(Resultant, 
		[route(Conn_Line, Start, Conn_Destination, TotalDuration)], Routes).

%Connected 8
connected(Source, Destination, Week, Day, Max_Duration, Max_Routes, Duration, Routes):-
	connected(Source, Destination, Week, Day, Max_Duration, Max_Routes, Duration, nil, [], Routes).
%Connected 10
connected(Source, Destination, Week, Day, Max_Duration, Max_Routes, Duration, Previous_station, Routes_sofar, Routes):-
	connected(Source, Destination, Week, Day, Max_Duration, Max_Routes, Duration,Previous_station, Routes_sofar,Routes, 0).

%Connected 11
connected(Source, Destination, Week, Day, Max_Duration, Max_Routes, Duration, _, RouteSoFar, Routes, DurationSoFar):-
	(
		connection(Destination, Source, ThisDuration, Line);
		connection(Source, Destination, ThisDuration, Line)), 
	proper_connection(Source, Destination, ThisDuration, Line), 
	line(Line, LineType), 
	 \+ strike(LineType, Week, Day), Duration is ThisDuration + DurationSoFar, Duration =< Max_Duration, 
	append_connection(Source, Destination, ThisDuration, Line, RouteSoFar, Routes), 
	length(Routes, Length), Length =< Max_Routes.
connected(Source, Destination, Week, Day, Max_Duration, Max_Routes, Duration, CameFrom, RouteSoFar, Routes, DurationSoFar):-
	connection(Source, SomeDestination, ThisDuration, Line), SomeDestination \= Destination, CameFrom \= SomeDestination, 
	proper_connection(Source, SomeDestination, ThisDuration, Line), 
	line(Line, LineType), 
	 \+ strike(LineType, Week, Day), SumDuration is ThisDuration + DurationSoFar, SumDuration =< Max_Duration, 
	append_connection(Source, SomeDestination, ThisDuration, Line, RouteSoFar, RoutesUpdated), 
	length(RoutesUpdated, Length), Length =< Max_Routes, 
	connected(SomeDestination, Destination, Week, Day, Max_Duration, Max_Routes, Duration, Source, RoutesUpdated, Routes, SumDuration).

connected(Source, Destination, Week, Day, Max_Duration, Max_Routes, Duration, CameFrom, RouteSoFar, Routes, DurationSoFar):-
	connection(SomeDestination, Source, ThisDuration, Line), SomeDestination \= Destination, CameFrom \= SomeDestination, 
	proper_connection(Source, SomeDestination, ThisDuration, Line), 
	line(Line, LineType), 
	 \+ strike(LineType, Week, Day), SumDuration is ThisDuration + DurationSoFar, SumDuration =< Max_Duration, 
	append_connection(Source, SomeDestination, ThisDuration, Line, RouteSoFar, RoutesUpdated), 
	length(RoutesUpdated, Length), Length =< Max_Routes, 
	connected(SomeDestination, Destination, Week, Day, Max_Duration, Max_Routes, Duration, Source, RoutesUpdated, Routes, SumDuration).
% Travel plan 
travel_plan(Home_Stations, Group, Max_Duration, Max_Routes, Journeys):-
	group_days(Group, Day_Timings), 
	travel_plan_helper(Home_Stations, Group, Max_Duration, Max_Routes, Day_Timings, Journeys).

travel_plan_helper(_,_,_,_,[],[]).
travel_plan_helper(Home_stations, Group, Max_Duration, Max_Routes,[day_timing(Week_Num, Week_Day)|Tail_day_time], [Head_journey|Tail_journey]):-
	campus_reachable(Destination), 
	member(Home_station, Home_stations),
    earliest_slot(Group, Week_Num, Week_Day, Slot_Num),
	connected(Home_station, Destination, Week_Num, Week_Day, Max_Duration, Max_Routes, Duration, Routes), 
	slot_to_mins(Slot_Num, Minutes), SDuration is Minutes - Duration, 
	mins_to_twentyfour_hr(SDuration, Start_hour, Start_min), 
	travel_plan_helper(Home_stations, Group, Max_Duration, Max_Routes, Tail_day_time, Tail_journey), 
	Head_journey = journey(Week_Num, Week_Day, Start_hour, Start_min, Duration, Routes).

%Time conversions
mins_to_twentyfour_hr(Minutes, TwentyFour_Hours, TwentyFour_Mins):-
	Hours is Minutes//60, Mins is Minutes mod 60, Mins = TwentyFour_Mins, Hours = TwentyFour_Hours.
twentyfour_hr_to_mins(TwentyFour_Hours, TwentyFour_Mins, Minutes):-
	Minutes is TwentyFour_Hours*60 + TwentyFour_Mins.
slot_to_mins(Slot_Num, Minutes):-
	slot(Slot_Num, Start_Hour, Start_Minute), 
	twentyfour_hr_to_mins(Start_Hour, Start_Minute, Minutes).
