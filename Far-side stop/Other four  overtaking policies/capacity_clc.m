% For calculating capacities under the NO policy,LO policy,and FO-UB policy
function [bus_stop_capacity,average_delay] = capacity_clc(berth_num_in,buffer_num_in,dist_num_in,cycle_length_in,service_cs_in,overtaking_in,overtaking_out)
global berth_num;
global back_headway;
global moveup_headway;
global run_step;
global lag_delay;
global time_step;
global thres_overtaking_in;
global thres_overtaking_out
global stop_entrance;
bus_stop_capacity = 0;
average_delay = 0;

bus = struct('mission',{},... 
             'lane_No',{},... 
             'current_lane',{},...
             'service_time',{},...
             'speed',{},...   
             'berthNo',{},... 
             'pro_overtaking_in',{},...
             'pro_overtaking_out',{},...
             'target_berth',{},...
             'enter_queue',{},...
             'start_run',{},...
             'enter_berth',{},...
             'end_step',{},...
             'service_finished',{},...
             'reaction_time',{},...
             'lanechange_time',{},...
             'wait_red_start',{},...
             'wait_red_end',{},...
             'enter_berth_time',{});

berth = struct('block',{},'current_bus',{},'potential_bus',{}); 
% -------simulation parameters------------%
% -------1. bus initiate parameters-------%
bus_num = 40000;        % simulation bus number
bus_flow_rate = 36000; % unit: vehicles/hour
lambda_bus = 1/(bus_flow_rate/3600);
bus_arrival_headway = exprnd(lambda_bus,1,bus_num); % pre-generate all buses arrival time
bus_service_meantime = 50; % unit: second
bus_service_variation = service_cs_in; % namely cs
bus_service_alpha = 1/(bus_service_variation^2); % service time follows Gamma distribution ~ alpha parameter                                
bus_service_beta = (bus_service_variation^2)/(1/bus_service_meantime); % service time follows Gamma distribution ~ bata parameter 
if bus_service_variation ~= 0
    bus_service_time = gamrnd(bus_service_alpha,bus_service_beta,1,bus_num); % pre-generate all buses service time
else
    bus_service_time = unifrnd (bus_service_meantime,bus_service_meantime,1,bus_num);
end
bus_overtaking_in = unifrnd (0,1,1,bus_num);
bus_overtaking_out = unifrnd (0,1,1,bus_num);
% -------2. rule set-------%
thres_overtaking_in = overtaking_in;    
thres_overtaking_out = overtaking_out;   
berth_num = berth_num_in;
buffer_num = buffer_num_in;
dist_num = dist_num_in; 
% -------3. signal parameters-------%
cycle_length = cycle_length_in;
green_ratio = 0.5;
green_time = green_ratio*cycle_length;
jam_spacing = 12;
free_speed = 40 / 3.6;
back_speed = 27 / 3.6;
moveup_speed = 20 / 3.6;
moveup_headway = jam_spacing / moveup_speed;
back_headway = jam_spacing / back_speed;
free_headway = jam_spacing / free_speed;
% -------4. output parameters-------%
last_bus_endtime = 0;
bus_arrival_time = zeros(1,bus_num);
bus_location = zeros(bus_num,1); 
berth_location = zeros(1,berth_num);
bus_location_plot = zeros(bus_num,200); 
buffer_location = zeros(1,buffer_num);
bus_running_list = [];
bus_lane_list = [];
adjacent_lane_list = [];
buffer_lane_list = [];
bus_queue_list = [];
unit_movlength = 4; 
intersection_length = dist_num*unit_movlength;
delate_arry = [];
bus(1).start_run = 1;
temp_berth_assigned = 0;

%-----初始化--------%
for n = 1:bus_num
    if n == 1
        bus_arrival_time(1) = bus_arrival_headway(1);
    else    
        bus_arrival_time(n) = bus_arrival_time(n-1)+bus_arrival_headway(n);
    end
    bus(n).service_time = bus_service_time(n);
    bus(n).pro_overtaking_in = bus_overtaking_in(n);
    bus(n).pro_overtaking_out = bus_overtaking_out(n);
    bus(n).berthNo = 0;
    bus(n).current_lane = 0;
    bus(n).lane_No = 0;
    bus(n).target_berth = 0;
    bus(n).reaction_time = 0;
    bus(n).mission = 0;
    bus(n).service_finished = 0;
    bus(n).lanechange_time = 0;
    bus(n).wait_red_start = 0;
    bus(n).wait_red_end = 0;
    bus(n).enter_berth_time = 0;
end
stop_entrance = 0; 
if buffer_num > 0
    for count = 1: buffer_num
        buffer_location(count) = unit_movlength*(buffer_num-count+1)+intersection_length;
    end
    stop_entrance = buffer_location(1);
else
    buffer_location(1) = intersection_length; 
    stop_entrance = buffer_location(1);
end

for count = 1: berth_num
    berth_location(count) = unit_movlength*(berth_num-count+1)+buffer_location(1);
  
    berth(count).potential_bus = 0;
    berth(count).current_bus = 0;
    berth(count).block = 0;
end


current_time = bus_arrival_time(1);
bus_count = 2;
run_step = 1;
bus_location(1) = 0;
time_step = moveup_headway/unit_movlength;
lag_delay = back_headway;
available_berth_num = 0; 
bus_time_interval = 0;
bus_queue_list(1) = 1;
bus(1).enter_queue = 1;
warm_up_endtime = 0;
warm_up_bus = 50;
while 1
    if bus_count <= bus_num && bus_time_interval >= moveup_headway && current_time >= bus_arrival_time(bus_count)
        if isempty(bus_queue_list) ~= 1  
            bus(bus_count).reaction_time = back_headway;
        end
        bus_queue_list(length(bus_queue_list)+1) = bus_count;
        bus(bus_count).enter_queue = run_step;
        bus_count = bus_count+1;
        bus_time_interval = 0;
    end

    if isempty(bus_queue_list) ~= 1
       if isempty(bus_running_list) || bus_location(bus_running_list(length(bus_running_list))) > 4 
           if bus(bus_queue_list(1)).reaction_time > 0
               bus(bus_queue_list(1)).reaction_time = bus(bus_queue_list(1)).reaction_time - time_step;
           end
           if bus(bus_queue_list(1)).reaction_time <= 0
               bus_running_list(length(bus_running_list)+1) = bus_queue_list(1);
               if bus_queue_list(1) == warm_up_bus
                   warm_up_endtime = current_time;  %warm-up process is over
               end 
               bus(bus_queue_list(1)).start_run = run_step-1;
               bus_location(bus_queue_list(1)) = 0;
               bus_location_plot(bus_queue_list(1),1) = 0;
               bus(bus_queue_list(1)).speed = 1;
               bus_queue_list(1) = []; 
           end
       else
           bus(bus_queue_list(1)).reaction_time = back_headway; 
           bus(bus_queue_list(1)).speed = 0;
       end 
    end
    for i = 1: length(bus_running_list)
        if i <= length(bus_running_list)
            if bus(bus_running_list(i)).mission == 0
                if bus(bus_running_list(i)).lane_No == 0
                    if is_possible_leavesignal(green_time,cycle_length,current_time) 
                       available_berth_num = check_vacant_berth(bus,berth);
                       if buffer_num ~= 0 && (((isempty(buffer_lane_list) ~=1 && isempty(find(bus_location(buffer_lane_list) == buffer_location(1))) ~=1 && bus(buffer_lane_list(bus_location(buffer_lane_list) == buffer_location(1))).speed == 0 && length(buffer_lane_list) >= buffer_num)...
                               || length(buffer_lane_list) >= (buffer_num+available_berth_num)) || (isempty(find(bus_location(buffer_lane_list) == buffer_location(buffer_num))) ~=1 && bus(buffer_lane_list(bus_location(buffer_lane_list) == buffer_location(buffer_num))).speed == 0))
                           bus(bus_running_list(i)).reaction_time = lag_delay; 
                           bus(bus_running_list(i)).speed = 0;
                       else
                           if buffer_num > 0
                               if bus(bus_running_list(i)).reaction_time > 0
                                   bus(bus_running_list(i)).reaction_time = bus(bus_running_list(i)).reaction_time - time_step;
                               else
                                     bus(bus_running_list(i)).speed = 1;
                                     bus(bus_running_list(i)).lane_No = 1;
                                     buffer_lane_list(length(buffer_lane_list)+1) = bus_running_list(i); 
                               end
                           else
                               berth = check_berth_state(bus_lane_list,bus,berth,bus_location,berth_location,adjacent_lane_list,berth_num,thres_overtaking_out);
                               [temp_berth_assigned,bus,berth] = update_target_berth(bus_running_list(i),bus,berth,bus_location,bus_lane_list,berth_location,adjacent_lane_list,berth_num,lag_delay,stop_entrance,thres_overtaking_in);
                               if temp_berth_assigned ~= 0
                                   bus(bus_running_list(i)).speed = 1;
                                   bus(bus_running_list(i)).mission = 1;
                                   bus(bus_running_list(i)).lane_No = 1;
                               else
                                   if bus_location(bus_running_list(i)) == 0  
                                       bus(bus_running_list(i)).reaction_time = back_headway; 
                                   else
                                       bus(bus_running_list(i)).reaction_time = lag_delay; 
                                   end
                               end
                           end
                       end  
                    else
                       bus(bus_running_list(i)).reaction_time = lag_delay; 
                       bus(bus_running_list(i)).speed = 0;
                    end
                end
                if bus(bus_running_list(i)).lane_No == 1 && bus(bus_running_list(i)).mission ~= 1
                    if is_possible_procede(bus_running_list(i),buffer_lane_list,bus,berth,bus_location,berth_location) 
                        [bus,berth,bus_location,buffer_lane_list] = move_forward(bus_running_list(i),bus,berth,bus_location,berth_location,buffer_location,buffer_lane_list,run_step,time_step,berth_num,back_headway,bus_running_list,buffer_num);
                    else
                        bus(bus_running_list(i)).reaction_time = back_headway; 
                        bus(bus_running_list(i)).speed = 0;
                    end
                    if bus_location(bus_running_list(i)) == buffer_location(1) 
                        bus(bus_running_list(i)).mission = 1;
                    end 
                    bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                    continue;
                end
            end
            if berth_num ~= 1 && bus(bus_running_list(i)).mission ~= 0 
                berth = check_berth_state(bus_lane_list,bus,berth,bus_location,berth_location,adjacent_lane_list,berth_num,thres_overtaking_out);
            end
            if bus(bus_running_list(i)).mission == 1 
                   [temp_berth_assigned,bus,berth] = update_target_berth(bus_running_list(i),bus,berth,bus_location,bus_lane_list,berth_location,adjacent_lane_list,berth_num,lag_delay,stop_entrance,thres_overtaking_in);
                    if temp_berth_assigned == 0 
                        if bus(bus_running_list(i)).target_berth ~= 0  
                            berth(bus(bus_running_list(i)).target_berth).potential_bus = 0;
                        end
                        bus(bus_running_list(i)).target_berth = 0;
                    else
                        bus(bus_running_list(i)).target_berth = temp_berth_assigned;
                    end   
                if bus(bus_running_list(i)).target_berth == 0  
                    if bus_location(bus_running_list(i)) < stop_entrance && buffer_num == 0  
                       bus(bus_running_list(i)).mission = 0;
                       bus(bus_running_list(i)).lane_No = 0; 
                       bus_location(bus_running_list(i)) = 0;
                    end  
                    if bus_location(bus_running_list(i)) == stop_entrance 
                        bus(bus_running_list(i)).reaction_time = back_headway;
                    else
                        bus(bus_running_list(i)).reaction_time = lag_delay; 
                    end
                    bus(bus_running_list(i)).speed = 0;
                    bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                    continue;
                end
                if bus(bus_running_list(i)).lane_No == 2  
                    if bus_location(bus_running_list(i)) < berth_location(bus(bus_running_list(i)).target_berth)
                        if bus(bus_running_list(i)).current_lane ~= bus(bus_running_list(i)).lane_No
                            bus(bus_running_list(i)).current_lane = 2;
                            adjacent_lane_list(length(adjacent_lane_list)+1) = bus_running_list(i); 
                            bus_lane_list(bus_lane_list == bus_running_list(i)) = [];
                        end
                        if is_possible_procede(bus_running_list(i),adjacent_lane_list,bus,berth,bus_location,berth_location)
                            [bus,berth,bus_location,buffer_lane_list] = move_forward(bus_running_list(i),bus,berth,bus_location,berth_location,buffer_location,buffer_lane_list,run_step,time_step,berth_num,back_headway,bus_running_list,buffer_num);
                        else
                            bus(bus_running_list(i)).reaction_time = back_headway; 
                            bus(bus_running_list(i)).speed = 0;
                        end
                        if bus_location(bus_running_list(i)) > berth_location(bus(bus_running_list(i)).target_berth+1) && berth(bus(bus_running_list(i)).target_berth).current_bus == 0
                            berth(bus(bus_running_list(i)).target_berth).current_bus = bus_running_list(i);  
                        end   
                        if bus_location(bus_running_list(i)) == berth_location(bus(bus_running_list(i)).target_berth) 
                            if is_possible_overtaking_in(bus_running_list(i),bus_lane_list,bus_location)
                               bus(bus_running_list(i)).lane_No = 1;
                               bus(bus_running_list(i)).current_lane = 1;
                               bus_lane_list = lane_change(bus_running_list(i),bus_lane_list,bus_location);
                               adjacent_lane_list(adjacent_lane_list == bus_running_list(i)) = [];
                               [bus,berth] = check_arrive_berth(bus_running_list(i),bus,berth,bus_location,berth_location);
                            else
                               bus(bus_running_list(i)).reaction_time = back_headway;
                            end  
                        end
                        bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                        continue;
                    else
                        if bus_location(bus_running_list(i)) == berth_location(bus(bus_running_list(i)).target_berth)
                           bus(bus_running_list(i)).speed = 0;
                           if bus_location(bus_running_list(i)) > berth_location(bus(bus_running_list(i)).target_berth+1) && berth(bus(bus_running_list(i)).target_berth).current_bus == 0
                               berth(bus(bus_running_list(i)).target_berth).current_bus = bus_running_list(i);
                           end 
                           if is_possible_overtaking_in(bus_running_list(i),bus_lane_list,bus_location) 
                               if bus(bus_running_list(i)).reaction_time >= 0
                                   bus(bus_running_list(i)).reaction_time = bus(bus_running_list(i)).reaction_time - time_step;  
                                   if bus(bus_running_list(i)).reaction_time <= 0
                                       bus(bus_running_list(i)).lane_No = 1;
                                       bus(bus_running_list(i)).current_lane = 1;
                                       bus_lane_list = lane_change(bus_running_list(i),bus_lane_list,bus_location);
                                       adjacent_lane_list(adjacent_lane_list == bus_running_list(i)) = [];
                                       [bus,berth] = check_arrive_berth(bus_running_list(i),bus,berth,bus_location,berth_location);
                                   end
                               end
                           else
                               bus(bus_running_list(i)).reaction_time = back_headway;
                           end
                           bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                           continue;
                        end
                    end   
                else  
                    if bus(bus_running_list(i)).current_lane ~= bus(bus_running_list(i)).lane_No
                        if bus(bus_running_list(i)).current_lane == 2 
                            if is_possible_overtaking_in(bus_running_list(i),bus_lane_list,bus_location)
                                if bus(bus_running_list(i)).reaction_time <= 0  
                                    bus(bus_running_list(i)).current_lane = 1;
                                    bus_lane_list = lane_change(bus_running_list(i),bus_lane_list,bus_location);
                                    adjacent_lane_list(adjacent_lane_list == bus_running_list(i)) = [];
                                    if bus_location(bus_running_list(i)) == berth_location(bus(bus_running_list(i)).target_berth)
                                        [bus,berth] = check_arrive_berth(bus_running_list(i),bus,berth,bus_location,berth_location);
                                        bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                                        continue;
                                    end
                                else
                                    bus(bus_running_list(i)).speed = 0;
                                    bus(bus_running_list(i)).reaction_time = bus(bus_running_list(i)).reaction_time - time_step; 
                                end
                            else
                                bus(bus_running_list(i)).speed = 0;
                                bus(bus_running_list(i)).reaction_time = back_headway; 
                                bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                                continue;
                            end
                        else
                            bus(bus_running_list(i)).current_lane = 1;
                            if isempty(find(bus_lane_list == bus_running_list(i))) == 1 
                                bus_lane_list(length(bus_lane_list)+1) = bus_running_list(i);
                            end
                        end
                    end
                    if bus(bus_running_list(i)).current_lane == 1
                        if bus_location(bus_running_list(i)) == berth_location(bus(bus_running_list(i)).target_berth)
                            [bus,berth] = check_arrive_berth(bus_running_list(i),bus,berth,bus_location,berth_location);
                            bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                            continue;
                        end
                        if is_possible_procede(bus_running_list(i),bus_lane_list,bus,berth,bus_location,berth_location)
                            [bus,berth,bus_location,buffer_lane_list] = move_forward(bus_running_list(i),bus,berth,bus_location,berth_location,buffer_location,buffer_lane_list,run_step,time_step,berth_num,back_headway,bus_running_list,buffer_num);
                        else 
                            bus(bus_running_list(i)).reaction_time = back_headway; 
                            bus(bus_running_list(i)).speed = 0;
                        end
                        if bus_location(bus_running_list(i)) > berth_location(bus(bus_running_list(i)).target_berth)-4 && berth(bus(bus_running_list(i)).target_berth).current_bus == 0
                            berth(bus(bus_running_list(i)).target_berth).current_bus = bus_running_list(i);  
                        end   
                        if bus_location(bus_running_list(i)) == berth_location(bus(bus_running_list(i)).target_berth)
                            [bus,berth] = check_arrive_berth(bus_running_list(i),bus,berth,bus_location,berth_location);
                            bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                            continue;
                        end
                    end
                end 
            end
            if bus(bus_running_list(i)).mission == 2 
                bus(bus_running_list(i)).speed = 0;
                if bus(bus_running_list(i)).service_time > 0
                    bus(bus_running_list(i)).service_time = bus(bus_running_list(i)).service_time - time_step;
                    if bus(bus_running_list(i)).reaction_time > 0
                        bus(bus_running_list(i)).reaction_time = bus(bus_running_list(i)).reaction_time - time_step;
                    end
                    if bus(bus_running_list(i)).lanechange_time > 0
                        bus(bus_running_list(i)).lanechange_time = bus(bus_running_list(i)).lanechange_time - time_step;
                    end
                else
                    bus(bus_running_list(i)).mission = 3;
                    bus(bus_running_list(i)).current_lane = 1;
                    berth(bus(bus_running_list(i)).berthNo).potential_bus = 0;
                    bus(bus_running_list(i)).service_finished = run_step-1;
                    if bus_location(bus_running_list(i)) == berth_location(1)  
                        bus(bus_running_list(i)).mission = 4;
                    end 
                end
            end
            if bus(bus_running_list(i)).mission == 3 
                if bus(bus_running_list(i)).current_lane == 1  
                    if bus(bus_running_list(i)).pro_overtaking_out <= thres_overtaking_out  
                        if bus(bus_running_list(i)).reaction_time <= 0 && is_possible_procede(bus_running_list(i),bus_lane_list,bus,berth,bus_location,berth_location)
                            [bus,berth,bus_location,buffer_lane_list] = move_forward(bus_running_list(i),bus,berth,bus_location,berth_location,buffer_location,buffer_lane_list,run_step,time_step,berth_num,back_headway,bus_running_list,buffer_num);
                            bus(bus_running_list(i)).lanechange_time = 0;
                        else                       
                           if is_possible_overtaking_out(bus_running_list(i),adjacent_lane_list,bus_location)
                               if bus(bus_running_list(i)).lanechange_time <= 0
                                   bus(bus_running_list(i)).reaction_time = 0;
                                   adjacent_lane_list = lane_change(bus_running_list(i),adjacent_lane_list,bus_location);
                                   bus(bus_running_list(i)).current_lane = 2;
                                   bus_lane_list(bus_lane_list == bus_running_list(i)) = [];
                                   if is_possible_procede(bus_running_list(i),adjacent_lane_list,bus,berth,bus_location,berth_location)
                                       [bus,berth,bus_location,buffer_lane_list] = move_forward(bus_running_list(i),bus,berth,bus_location,berth_location,buffer_location,buffer_lane_list,run_step,time_step,berth_num,back_headway,bus_running_list,buffer_num);
                                   else
                                       bus(bus_running_list(i)).reaction_time = back_headway; 
                                       bus(bus_running_list(i)).speed = 0;
                                   end
                               else
                                   bus(bus_running_list(i)).speed = 0;
                                   bus(bus_running_list(i)).lanechange_time = bus(bus_running_list(i)).lanechange_time-time_step; 
                                   bus(bus_running_list(i)).reaction_time = bus(bus_running_list(i)).reaction_time - time_step; 
                               end
                           else
                               bus(bus_running_list(i)).lanechange_time = back_headway; 
                               bus(bus_running_list(i)).speed = 0;
                               bus(bus_running_list(i)).reaction_time = bus(bus_running_list(i)).reaction_time - time_step;
                           end
                        end
                    else  % 不能超车出去
                        if is_possible_procede(bus_running_list(i),bus_lane_list,bus,berth,bus_location,berth_location)
                            [bus,berth,bus_location,buffer_lane_list] = move_forward(bus_running_list(i),bus,berth,bus_location,berth_location,buffer_location,buffer_lane_list,run_step,time_step,berth_num,back_headway,bus_running_list,buffer_num);                
                        else
                            bus(bus_running_list(i)).reaction_time = back_headway; 
                            bus(bus_running_list(i)).speed = 0;
                        end 
                    end
                else
                    if bus(bus_running_list(i)).current_lane == 2 
                       if is_possible_procede(bus_running_list(i),adjacent_lane_list,bus,berth,bus_location,berth_location)
                           [bus,berth,bus_location,buffer_lane_list] = move_forward(bus_running_list(i),bus,berth,bus_location,berth_location,buffer_location,buffer_lane_list,run_step,time_step,berth_num,back_headway,bus_running_list,buffer_num);
                       else
                           bus(bus_running_list(i)).reaction_time = back_headway;  
                           bus(bus_running_list(i)).speed = 0;
                       end
                    end
                end
                if bus_location(bus_running_list(i)) == berth_location(1) 
                    bus(bus_running_list(i)).mission = 4;
                    bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
                    continue;
                end
            end
            if bus(bus_running_list(i)).mission == 4 
                if bus(bus_running_list(i)).reaction_time > 0
                    bus(bus_running_list(i)).reaction_time = bus(bus_running_list(i)).reaction_time - time_step;
                    bus(bus_running_list(i)).speed = 0; 
                else
                    bus_location(bus_running_list(i)) = bus_location(bus_running_list(i)) + 1;
                    bus(bus_running_list(i)).speed = 1;
                    if bus(bus_running_list(i)).current_lane == 1 && berth(1).current_bus == bus_running_list(i) 
                        berth(1).current_bus = 0;
                        if berth_num ~= 1 && berth(2).current_bus ~= 0 && bus(berth(2).current_bus).speed == 0 
                            bus(berth(2).current_bus).reaction_time = back_headway;
                            bus(berth(2).current_bus).lanechange_time = back_headway;
                        end
                    end
                end
                if bus_location(bus_running_list(i)) >= berth_location(1) + 1
                    delate_arry(length(delate_arry)+1) = bus_running_list(i);
                    bus(bus_running_list(i)).speed = 0;
                    bus(bus_running_list(i)).end_step = run_step;
                end
            end
            bus_location_plot(bus_running_list(i),run_step-bus(bus_running_list(i)).start_run+1) = bus_location(bus_running_list(i));
        end
    end
    if isempty(delate_arry) ~= 1
        for k = 1:length(delate_arry)
            if k <= length(delate_arry) && delate_arry(k) ~= 0
                adjacent_lane_list(adjacent_lane_list == delate_arry(k)) = [];
                bus_lane_list(bus_lane_list == delate_arry(k)) = [];
                bus_running_list(bus_running_list == delate_arry(k)) = []; 
                delate_arry(k) = 0;
            end
        end
        delate_arry = [];
    end
    for m = 0:length(bus_running_list)-2
        for n = 0:length(bus_running_list)-2-m
            if bus_location(bus_running_list(n+1)) < bus_location(bus_running_list(n+2))
                delate_arry = bus_running_list(n+1);
                bus_running_list(n+1) = bus_running_list(n+2);
                bus_running_list(n+2) = delate_arry;
            end
        end
    end
    delate_arry = [];
    if bus_count >= bus_num && isempty(bus_running_list) && isempty(bus_queue_list) 
        last_bus_endtime = current_time;
        break;
    end
    run_step = run_step+1;  
    current_time = current_time+time_step;
    bus_time_interval = bus_time_interval+time_step;
end  
% ------output capacity------------%
bus_stop_capacity = (bus_num-warm_up_bus+1) / ((last_bus_endtime - warm_up_endtime)/3600);

end