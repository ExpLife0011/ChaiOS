BITS 32
section .text

;Parameters on the stack. Order does not matter
;Returns in EDX:EAX
global __allmul
__allmul:
push ebp
mov ebp, esp

mov eax, [ebp+12]		;High DWORD
mov ecx, [ebp+20]		;High DWORD

;If both high DWORDs are zero, we multiply the low 32 bits only
or eax, ecx
cmp eax, 0
mov eax, [ebp+8]		;Low DWORD
mov ecx, [ebp+16]		;Low DWORD
je .lowmultiply

;Full 64 bit multiply. We first do the low DWORDs, then the High DWORDs. with the Low DWORDs (note high*high >2^64)
;iAPX 186/188 manual says that CF and OF are set if the high DWORD (EDX) is set on MUL
;Therefore, we just return after truncating the high 32 bits.
mul ecx
;Non-volatile registers
push esi
push edi

;Store the result of low multiply for later
mov esi, eax	;Low
mov edi, edx	;High

mov eax, [ebp+12]	;High multiply
mov ecx, [ebp+16]	;Low DWORD
mul ecx
add edi, eax		;"Low" of result is actually high

mov eax, [ebp+8]	;Low bits
mov ecx, [ebp+20]	;high DWORD
mul ecx

add edi, eax

;The final result
mov eax, esi
mov edx, edi

pop edi
pop esi

jmp .end

.lowmultiply:
;x86 stores result in EDX:EAX, as required.
mul ecx

.end:
leave
ret 16

;Parameters are on the stack. a/b. a is at ebp+8, b at ebp+16
;EDX:EAX contains quotient on return. Remainder is not returned
global __aulldiv
__aulldiv:
push ebp
mov ebp, esp

push ebx
push edi

;Set up so that ecx:ebx is divisor
mov ebx, [ebp+16]
mov ecx, [ebp+20]
;edx:eax will be numerator
mov eax, [ebp+8]
mov edx, [ebp+12]

;See if divsior is smaller than 2**32
mov ecx, ecx
jnz .loop		;Divsor is quite big.
mov edi, edx
mov eax, edx	;High of numerator
xor edx, edx
div ebx			;Only bits of divsor
;What we have now is high bits of result in eax.
mov ecx, eax	;Stash out of the way
mov eax, [ebp+8]	;Low bits
div ebx
mov edx, ecx

jmp .end


;Weird algorithm, but it works. We clear high bits, then divide. Result may be out by 1
.loop:
shr ecx, 1
rcr ebx, 1
shr edx, 1
rcr eax, 1
test ecx, ecx
jnz .loop
;Divide, ignore remainder
div ebx
mov edi, eax
;Check result by multiplying back
mul dword[ebp+20]
mov ecx, eax
mov eax, [ebp+16]
mul edi
add edx, ecx
jc .out

;Check that we are <=
cmp edx, [ebp+12]
ja .out
jb .makeresult
cmp eax, [ebp+8]
jbe .makeresult

.out:
dec edi

.makeresult:
xor edx, edx
mov eax, esi

.end:
pop edi
pop ebx

leave
ret 16