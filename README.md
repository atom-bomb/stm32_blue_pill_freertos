# stm32_blue_pill_freertos

here is a simple, minimal example project that gets multithreading running
on an stm32 'blue pill' dev board.

the build scripts are setup to use docker, so the only build requirement is
that you have gmake installed and docker running.

## build

```
make
```

## install

move the boot0 jumper to 1
connect your favorite USB UART thing then

```
make flash
```

move the boot0 jumper back to 0
press the reset button

NB, makefiles assume that your USB UART thing is /dev/ttyUSB0.
if it isn't, you might need to do something different.
