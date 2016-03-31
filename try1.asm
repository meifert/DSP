        .mmregs
        .ps     0080ah
        B       RINT
        .ps     00a00h
        .entry
        LDP     DXR
        LAMM    IMR
        OR      #10h
        SAMM    IMR
LOOP:   ADD     #10
        SACL    DXR,3
        IDLE
        B       LOOP
RINT:   RETE

