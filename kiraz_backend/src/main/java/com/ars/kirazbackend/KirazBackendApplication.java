package com.ars.kirazbackend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class KirazBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(KirazBackendApplication.class, args);
	}

}
