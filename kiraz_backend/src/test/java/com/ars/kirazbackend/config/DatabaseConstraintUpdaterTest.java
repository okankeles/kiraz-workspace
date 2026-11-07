package com.ars.kirazbackend.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DatabaseConstraintUpdaterTest {

    @Mock
    private JdbcTemplate jdbcTemplate;

    @InjectMocks
    private DatabaseConstraintUpdater updater;

    @Test
    void testUpdateUsersRoleCheckConstraint_ExecutesDropAndAdd() {
        updater.updateUsersRoleCheckConstraint();

        verify(jdbcTemplate, atLeastOnce()).execute(contains("DROP CONSTRAINT IF EXISTS users_role_check"));
        verify(jdbcTemplate, atLeastOnce()).execute(contains("ADD CONSTRAINT users_role_check CHECK"));
    }

    @Test
    void testUpdateUsersRoleCheckConstraint_WhenExceptionOccurs_GracefullyHandled() {
        doThrow(new RuntimeException("DB error")).when(jdbcTemplate).execute(contains("ADD CONSTRAINT"));

        // Should not throw exception
        updater.updateUsersRoleCheckConstraint();

        verify(jdbcTemplate, atLeast(2)).execute(contains("DROP CONSTRAINT IF EXISTS users_role_check"));
    }
}
