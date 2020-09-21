function inRange = CheckTimeOfDay(startHour, stopHour)

    timeOfDay = datetime;

    if startHour < stopHour
        inRange = (timeOfDay.Hour > startHour) && (timeOfDay.Hour < stopHour);
    elseif startHour > stopHour
        inRange = (timeOfDay.Hour > startHour) || (timeOfDay.Hour < stopHour);
    else
        inRange = true;
    end

end
