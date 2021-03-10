#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

#include <stm32f10x.h>
#include <stm32f10x_gpio.h>
#include <stm32f10x_rcc.h>
#include <stm32f10x_usart.h>
#include <misc.h>

void vThread1( void *pvParameters );
void vThread2( void *pvParameters );

const char *pvThread1  = "Hello from Thread 1.\r\n";
const char *pvThread2  = "Hello from Thread 2.\r\n";

/*-----------------------------------------------------------*/
/* Global semaphore variable */
SemaphoreHandle_t xSemaphore = NULL; 

int __io_putchar(int ch) {
  USART_SendData(USART1, (uint8_t)ch);
  while (USART_GetFlagStatus(USART1, USART_FLAG_TC) == RESET) {}

  return ch;
}

int _write(int fd, char * ptr, int len) {
  int i=0;

  while (i < len)
    __io_putchar(ptr[i++]);
  return len;
}

void gpio_init(void) {
  /* GPIO structure for port initialization */
  GPIO_InitTypeDef GPIO_Settings;

  /* enable clock on APB2 */
  RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOC, ENABLE);

  /* configure port C13 for driving an LED */
  GPIO_Settings.GPIO_Pin = GPIO_Pin_13;
  GPIO_Settings.GPIO_Mode = GPIO_Mode_Out_PP;
  GPIO_Settings.GPIO_Speed = GPIO_Speed_2MHz;
  GPIO_Init(GPIOC, &GPIO_Settings);
}

void set_led(bool on) {
  if (on)
    GPIO_ResetBits(GPIOC, GPIO_Pin_13);
  else
    GPIO_SetBits(GPIOC, GPIO_Pin_13);
}

void usart_init() {
  GPIO_InitTypeDef GPIO_Settings;
  USART_InitTypeDef USART_Settings;

  RCC_APB2PeriphClockCmd(RCC_APB2Periph_USART1, ENABLE);
  RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA, ENABLE);

  GPIO_StructInit(&GPIO_Settings);
  GPIO_Settings.GPIO_Pin = GPIO_Pin_9;
  GPIO_Settings.GPIO_Mode = GPIO_Mode_AF_PP;
  GPIO_Settings.GPIO_Speed = GPIO_Speed_2MHz;
  GPIO_Init(GPIOA , &GPIO_Settings);

  GPIO_Settings.GPIO_Pin = GPIO_Pin_10;
  GPIO_Settings.GPIO_Mode = GPIO_Mode_IN_FLOATING;
  GPIO_Settings.GPIO_Speed = GPIO_Speed_2MHz;
  GPIO_Init(GPIOA , &GPIO_Settings);

  USART_StructInit(&USART_Settings);
  USART_Settings.USART_BaudRate = 9600;
  USART_Settings.USART_WordLength = USART_WordLength_8b;
  USART_Settings.USART_StopBits = USART_StopBits_1;
  USART_Settings.USART_Parity = USART_Parity_No;
  USART_Settings.USART_HardwareFlowControl = USART_HardwareFlowControl_None;
  USART_Settings.USART_Mode = USART_Mode_Rx | USART_Mode_Tx;
  USART_Init(USART1, &USART_Settings);

  USART_ITConfig(USART1, USART_IT_RXNE, ENABLE);
  USART_Cmd(USART1, ENABLE);

  NVIC_InitTypeDef NVIC_Settings;

  NVIC_PriorityGroupConfig(NVIC_PriorityGroup_4);

  NVIC_Settings.NVIC_IRQChannel = USART1_IRQn;
  NVIC_Settings.NVIC_IRQChannelSubPriority = 0;
  NVIC_Settings.NVIC_IRQChannelCmd = ENABLE;
  NVIC_Init(&NVIC_Settings);

  while (USART_GetFlagStatus(USART1, USART_FLAG_TC) == RESET) {}
}

void USART1_IRQHandler() {
  unsigned char received;

  if (USART_GetITStatus(USART1, USART_IT_RXNE) != RESET) {
    received = USART_ReceiveData(USART1);
    __io_putchar(received);
  }
}

int main( void ) {
  gpio_init();
  set_led(false);

  usart_init();

  xTaskCreate(vThread1, "Thread 1", configMINIMAL_STACK_SIZE,
	(void*)pvThread1, 1, NULL);

  xTaskCreate(vThread2, "Thread 2", configMINIMAL_STACK_SIZE,
	(void*)pvThread2, 1, NULL);

  xSemaphore = xSemaphoreCreateBinary();
  xSemaphoreGive( xSemaphore);
  vTaskStartScheduler();
  for( ;; );
}

void vThread1(void *pvParameters) {
  char *pcThreadMsg = (char *) pvParameters;

  for( ;; ) {
    xSemaphoreTake(xSemaphore,(TickType_t) portMAX_DELAY);
    printf(pcThreadMsg);
    xSemaphoreGive(xSemaphore);
    vTaskDelay( 2000 / portTICK_PERIOD_MS );
  }
}

void vThread2(void *pvParameters) {
  char *pcThreadMsg = (char *) pvParameters;

  for( ;; ) {
    xSemaphoreTake(xSemaphore,(TickType_t) portMAX_DELAY);
    printf(pcThreadMsg);
    xSemaphoreGive(xSemaphore);
    vTaskDelay( 2000 / portTICK_PERIOD_MS );
  }
}
