package com.ars.kirazbackend.event;

import java.io.Serializable;
import java.time.LocalDateTime;

public record ManagerAssignedEvent(
        Long propertyId,
        String propertyName,
        String managerEmail,
        String landlordName,
        LocalDateTime timestamp
) implements Serializable {

    public ManagerAssignedEvent(Long propertyId, String propertyName, String managerEmail, String landlordName) {
        this(propertyId, propertyName, managerEmail, landlordName, LocalDateTime.now());
    }
}
