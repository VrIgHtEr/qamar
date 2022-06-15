ENTRY(_start);
SECTIONS {
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
    __bss_size = ((__bss_end)-(__bss_start));
    /DISCARD/ : {
        *(.note.gnu.build-id);
    }
}
