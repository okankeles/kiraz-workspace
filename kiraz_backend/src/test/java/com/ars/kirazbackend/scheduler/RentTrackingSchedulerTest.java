package com.ars.kirazbackend.scheduler;

import com.ars.kirazbackend.service.RentPeriodService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RentTrackingSchedulerTest {

    @Mock
    private RentPeriodService rentPeriodService;

    @InjectMocks
    private RentTrackingScheduler scheduler;

    @Test
    void testTrackOverdueRentPayments_CallsRentPeriodService() {
        when(rentPeriodService.markOverduePeriods()).thenReturn(5);

        scheduler.trackOverdueRentPayments();

        verify(rentPeriodService, times(1)).markOverduePeriods();
    }
}
