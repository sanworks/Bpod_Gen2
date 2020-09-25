function inRange = CheckTimeOfDay(startHour, stopHour)

    timeOfDay = datetime;
    thisHour = timeOfDay.Hour + timeOfDay.Minute / 60;

    if startHour < stopHour
        inRange = (thisHour >= startHour) && (thisHour < stopHour);
    elseif startHour > stopHour
        inRange = (thisHour >= startHour) || (thisHour < stopHour);
    else
        inRange = true;
    end

end
