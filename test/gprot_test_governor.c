/*
 * Open-BLDC - Open BrushLess DC Motor Controller
 * Copyright (C) 2009 by Piotr Esden-Tempski <piotr@esden.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 */
/**
 * @file   gprot_test_governor.c
 * @author Piotr Esden-Tempski <piotr@esden.net>
 *
 * @brief  Governor application specific implemetation used for the governor test
 *
 */

#include <libopencm3/stm32/f1/gpio.h>

#include <lg/gpdef.h>
#include <lg/gprotc.h>

#include "gprot_test_governor.h"
#include "driver/led.h"
#include "driver/usart.h"

static void gprot_trigger_output(void *data);
static void gprot_register_changed(void *data, u8 addr);
static void gprot_get_version(void *data);

static bool gprot_get_version_triggered;

#ifndef PROJECT_NAME
#define PROJECT_NAME "null"
#endif

#ifndef TARGET
#define TARGET "null"
#endif

#ifndef VERSION
#define VERSION "null"
#endif

#ifndef	VERSION_SUFFIX
#define VERSION_SUFFIX "null"
#endif

#ifndef BUILDDATE
#define BUILDDATE "null"
#endif

#ifndef COPYRIGHT
#define COPYRIGHT "null"
#endif

#ifndef LICENSE
#define LICENSE "null"
#endif

#define FIRMWARE_VERSION "\n" PROJECT_NAME " " TARGET " firmware " \
			 VERSION VERSION_SUFFIX ", build " BUILDDATE "\n"
#define FIRMWARE_COPYRIGHT COPYRIGHT "\n"
#define FIRMWARE_LICENSE LICENSE "\n"

/**
 * Test governor registers.
 */
static u16 test_regs[32];

/* Function implementations */
/**
 * Initialize the Governor protocol subsystem.
 */
void gprot_init()
{
	int i;

	(void)gpc_init(gprot_trigger_output, 0, gprot_register_changed, 0);
	(void)gpc_set_get_version_callback(gprot_get_version, 0);

	gprot_get_version_triggered = false;

	for (i = 0; i < 32; i++) {
		test_regs[i] = (uint16_t)(i * 3);
		if (gpc_setup_reg((uint8_t)i, &test_regs[i]) != 0) {
			ON(LED_RED);
		}
	}

}

/**
 * Is called by libgovernor when it wants to send data out.
 *
 * In our case we enable the tx interrupt of the usart driver here.
 *
 * @param data Passthrough data of the callback. (ignored here)
 */
void gprot_trigger_output(void *data)
{
	data = data;
	TOGGLE(LED_RED);
	usart_enable_send();
}

/**
 * Callback from libgovernor indicating a change in a register.
 *
 * @param data Passthrough data to the callback.
 * @param addr Address of the register that changed.
 */
void gprot_register_changed(void *data, u8 addr)
{
	data = data;
	addr = addr;
}

/**
 * Callback from libgovernor indicating a get version event.
 *
 * @param data Passthrough data to the callback.
 */
void gprot_get_version(void *data)
{
	data = data;

	gprot_get_version_triggered = true;
}

/**
 * Userspace process handling the get version event.
 */
void gprot_get_version_process(void)
{
	if (gprot_get_version_triggered) {
		gprot_get_version_triggered = false;
		gpc_send_string(FIRMWARE_VERSION, sizeof(FIRMWARE_VERSION));
		gpc_send_string(FIRMWARE_COPYRIGHT, sizeof(FIRMWARE_COPYRIGHT));
		gpc_send_string(FIRMWARE_LICENSE, sizeof(FIRMWARE_LICENSE));
	}
}
