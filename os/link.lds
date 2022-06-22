ENTRY(_start);

SECTIONS {
    __ram_size = 64k;
    __ram_end = ((__ram_size)-1);
    __stack_size = 0x8000;
    __stack_base = (__ram_size);
    __stack_top = ((__stack_base)-(__stack_size));
    . = 0x000000;
    .text : {
        *(.text.prologue);
        *(.text*);
    }
    .data : {
        __data_start = .;
        *(.data*);
    }
    .rodata : {
        *(.rodata*);
    }
    .bss : {
        __bss_start = .;
        *(COMMON);
        *(.bss);
        . = ALIGN(4);
        __bss_end = .;
    }
    __heap_start = __bss_end;
    __bss_size = ((__bss_end)-(__bss_start));
    __heap_size = ((__stack_top)-(__bss_end));
    /DISCARD/ : {
        *(.note.gnu.build-id);
    }
}
