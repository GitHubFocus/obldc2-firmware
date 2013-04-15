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

/**
 * @file   sys_tick_main.c
 * @author Piotr Esden-Tempski <piotr@esden.net>
 * @date   Tue Aug 17 01:41:29 2010
 *
 * @brief  Sys Tick soft timer test implementation.
 *
 */

#include <libopencm3/stm32/f1/gpio.h>

#include "driver/mcu.h"
#include "driver/led.h"
#include "driver/sys_tick.h"

static void sys_tick_timer_callback(int id);
static void sys_tick_timer_callback_one_shot(int id);

/**
 * Callback from the soft sys tick timer
 */
void sys_tick_timer_callback(int id) {
    id = id;

    TOGGLE(LED_GREEN);
    (void)sys_tick_timer_register(sys_tick_timer_callback_one_shot, 1000);
}

/**
 * One shot callback from the soft Sys Tick timer
 */
void sys_tick_timer_callback_one_shot(int id) {
    static int state = 0;
    if (state == 0) {
        sys_tick_timer_update(id, 1000);
        state++;
    } else {
        sys_tick_timer_unregister(id);
        state--;
    }
    TOGGLE(LED_RED);
}

/**
 * Sys Tick soft timer test main function
 */
int main(void) {
    uint32_t timer;

    mcu_init();
    led_init();
    sys_tick_init();

    (void)sys_tick_timer_register(sys_tick_timer_callback, 10000);

    while (true) {
        timer = sys_tick_get_timer();
        while (!sys_tick_check_timer(timer, 500)) {
            __asm("nop");
        }
        // TOGGLE(LED_ORANGE);
    }
}
