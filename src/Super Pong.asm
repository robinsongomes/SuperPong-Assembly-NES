;/////////////////////////////////////////////
;// Super Pong
;//
;// Assembly para NES
;//
;// Criado por Robinson
;//
;//
;// O deseonvolvimento desse projeto teve como finalidade aprender
;//sobre a arquitetura e o funcionamento de um video game antigo,
;//e ver algumas dificuldades que eram enfrenteadas na produção de um jogo
;//com recursos limitados.
;//
;//
;//
;//  Configurações do NES:
;//- CPU baseada no processador MOS Technology 6502
;//- 2 KiB de memoria RAM principal
;//- 48 KiB de memoria ROM
;//- Tiles com 8X8 pixels
;//- 32X30 Tiles =  256 x 240 pixels de resolução
;//- Paleta com 48 cores, 3 cores por tiles
;//
;// 
;// Ferramentas utilizadas:
;// - Assembler NESASM3
;// - Editor grafico YY-CHR e NES Screen Tool
;// - Emulador FCEUX
;//
;/////////////////////////////////////////////


	.inesprg 1   ; 1x 16KB bank of PRG code
	.ineschr 1   ; 1x 8KB bank of CHR data
	.inesmap 0   ; mapper 0 = NROM, no bank swapping
	.inesmir 1   ; background mirroring

;////////////////////////
;// Declarar Variaveis //
;////////////////////////

	.rsset $0000


;valores usados para contas e rotinas especificas
;veja as rotinas no final do bank 1

math_x					.rs 1	;valor 1
math_y					.rs 1	;valor 2
math_r					.rs 1	;resultado das contas

;valores temporarios dos registradores
registrador_a			.rs 1
registrador_x			.rs 1
registrador_y			.rs 1	;guarda temporariamente os valores para pegalos novamente depois de executar uma rotina

;calcular colisao
colisao_x_1				.rs 1
colisao_y_1				.rs 1
colisao_w_1				.rs 1
colisao_h_1				.rs 1

colisao_x_2				.rs 1
colisao_y_2				.rs 1
colisao_w_2				.rs 1
colisao_h_2				.rs 1

colisao_return			.rs 1


;;;;;;;;;;;;;;;;;;;;;;;
estado_botao			.rs 1 	;Referente ao botao 'A', 00 - nao precionado, 01 - precionado


gamestate				.rs 1

ball_x					.rs 1
ball_y					.rs 1

ball_dir_x				.rs 1 	;00 = esquerda, 01 = direita
ball_dir_y				.rs 1 	;00 = cima    , 01 = baixo

ballspeed_x				.rs 1
ballspeed_y				.rs 1

rebatida				.rs 1 	;a cada 2 batidas aumentar velocidade


controle1 				.rs 1
controle2				.rs 1

player1_x				.rs 1
player1_y				.rs 1
player2_x				.rs 1
player2_y				.rs 1
player_speed			.rs 1

marcador 				.rs 1 	;numero da opcao, 00 = 1 jogador, 01 = 2 jogadores
marcador_pos_y			.rs 1 	;160 na opcao 0, 176 na opcao 1 (decimal)

score1					.rs 1
score2					.rs 1

vencedor 				.rs 1


valor_temporario		.rs 1 	;variavel temporaria, para uso geral


Low_Byte_Background 	.rs 1 	;usado no carregamento do background
High_Byte_Background	.rs 1

tipo_background			.rs 1	;para definir qual background sera carregado
								; #$00 = vazia, carrega todos os tiles com o valor $#FF
								; #$01 = titulo
								; #$02 = campo
								; #$03 = gameover


;Declarar constantes

STATE_TITLE		= $00
STATE_PLAY		= $01
STATE_GAMEOVER	= $02

WALL_RIGTH		= $F4	;244 em decimal
WALL_TOP		= $08	; 10 em decimal
WALL_BOTTOM		= $D8	;216 em decimal (formato NTSC)
WALL_LEFT		= $04


;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;

	.bank 0
	.org $C000

RESET:
	SEI          ; disable IRQs
	CLD          ; disable decimal mode
	LDX #$40
	STX $4017    ; disable APU frame IRQ
	LDX #$FF
	TXS          ; Set up stack
	INX          ; now X = 0
	STX $2000    ; disable NMI
	STX $2001    ; disable rendering
	STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
	BIT $2002
	BPL vblankwait1

	;preservar estado do botao
	LDY estado_botao

clrmem:
	LDA #$00
	STA $0000, x
	STA $0100, x
	STA $0300, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	STA $0200, x
	INX
	BNE clrmem

	;restaurar estado do botao
	STY estado_botao

vblankwait2:      ; Second wait for vblank, PPU is ready after this
	BIT $2002
	BPL vblankwait2

;/////////////////////
;// Carregar Paleta //
;/////////////////////

LoadPaletas:
	LDA $2002	;Ler PPU para resetar high/low
	
	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006	;Escrever $3F00, endereco das paletas

	LDX #$00
LoadPaletas_Loop:
	LDA Paleta, X 			;carregar endereco da paleta + X em cada loop
	STA $2007				;escrever na ppu
	
	INX						;X ++
	CPX #32					;comprar se leu todos os valores
	BNE LoadPaletas_Loop



;;;;;Carregar Titulo
;;;;;;;;;;;;;;;;;;;;
;reseta as variaveis e carrega o background junto com os atributos
	LDA #STATE_TITLE
	STA gamestate

	JSR Carregar_Novo_Estado


Loop:
	JMP Loop 			;o programa entra em loop inifinito esperando pelo NMI (uma atualizaca da tela)


NMI:
	;Atualizar DMA , basicamente joga os sprites na PPU para serem mostrados na tela
	LDA #$00
	STA $2003
	LDA #$02
	STA $4014

	;nao faz scolling do background
	LDA #$00
  	STA $2005
  	STA $2005

	;Passar para a subrotina gemeengine
	JSR GameEngine

	;Retornar de onde foi interrompido (no loop)
	RTI


;//////////////////////////////////////////////////
;///////////////// SUB Rotinas ////////////////////
;//////////////////////////////////////////////////


;////////////////
;//Game Engine///
;////////////////
;Dependendo do estado do game state chama subrotinas diferentes
GameEngine:
	
	LDA gamestate
	CMP #STATE_TITLE
	BEQ Engine_Title

	LDA gamestate
	CMP #STATE_PLAY
	BEQ Engine_Play

	LDA gamestate
	CMP #STATE_GAMEOVER
	BEQ Engine_GameOver

	RTS ;retornar para o 'NMI'

;;;;;;;;;;;;;;;;;;;


;///////////////////////////
;////// STATE TITLE ////////
;///////////////////////////


Engine_Title:

	JSR LerControle_1 		;apenas le as entradas do controle e salva na memoria

	JSR Title_Menu 			;trata os eventos do controle movendo o marcador, ou entrando no jogo, de acordo com os botes apertados

	JSR Title_DrawMarcador	;desenha o sprite do marcador
	
	RTS 					;retorna para 'GameEngine'



;///////////////////////////
;////// STATE PLAY /////////
;///////////////////////////


Engine_Play:
	
	JSR LerControle_1 			;le as entradas dos controle e salva na memoria
	JSR LerControle_2
	
	JSR MoverPlayer_1 			;movimenta os jogadores 1 de acordo com os controles
	JSR MoverPlayer_2
	
	
	JSR MoverBola 				;movimenta a bola	
	JSR ChecarColisao_Bola		;checa colisoes e reposiciona a bola caso necessario
	
	JSR DrawSprites 			;Desenha os jogadores e a bola	
	JSR DrawScore 				;Desenha a pontuacao

	RTS 						;retorna para 'GameEngine'


;///////////////////////////
;///// STATE GAMEOVER //////
;///////////////////////////

Engine_GameOver:
	
	JSR LerControle_1 			;Le os controles

	JSR GameOver_Continuar 		;Espera pelo jogador apertar o botao 'A'

	JSR GameOver_Draw			;Desenha quem ganhou

	RTS 						;retorna para 'GameEngine'


;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;Fim das engines;;;;;;;


;///////////////////////
;// Carregar Estados ///
;///////////////////////

;Le o estado do endereco 'gamestate' e altera o background conforme necessario
Carregar_Novo_Estado:
	LDA gamestate


	;;;;Carregar STATE_TITLE;;;;;;
	CMP #STATE_TITLE
	BNE Done_Carregar_Estado_Title
		;;;;resetar variaveis;;;;
		;Marcador de opcoes do menu
		LDA #$00
		STA marcador
		LDA #160
		STA marcador_pos_y

		;Bola
		LDA #$00
		STA ball_dir_x	;definir para esquerda
		STA ball_dir_y	;definir para cima

		;posicao
		JSR ResetarBola
		LDA #$00
		STA rebatida

		
		;Players
		LDA #WALL_LEFT
		STA player1_x
		LDA #WALL_RIGTH-4
		STA player2_x
		LDA #$00
		STA score1
		STA score2		

		LDA #(240 / 2) - 8
		STA player1_y
		STA player2_y

		LDA #06
		STA player_speed

		;Carregar background do titulo
		;alterar tipo background que sera carregado
		LDA #$01;title
		STA tipo_background

		;e necessario resetar a ppu para que o novo background carrege normalmente
		LDA #$00
		STA $2000
		STA $2001

		JSR LoadBackground

		;ativar PPU novamente
		LDA #%10000000   	;habilita NMI, define a Pattern Table do background e sprite como 0
		STA $2000

		LDA #%00011110   	;habilitar sprites, background e retirar uma especie de corte no lado esquerdo
		STA $2001
	Done_Carregar_Estado_Title:


	;;;;Carregar STATE_PLAY;;;;;;
	CMP #STATE_PLAY
	BNE Done_Carregar_Estado_Play

		;alterar tipo background que sera carregado
		LDA #$02;campo
		STA tipo_background

		;e necessario resetar a ppu para que o novo background carrege normalmente
		LDA #$00
		STA $2000
		STA $2001

		JSR LoadBackground

		;ativar PPU novamente
		LDA #%10011000   	;habilita NMI, define a Pattern Table do background e sprite como 1
		STA $2000

		LDA #%00011110   	;habilitar sprites, background e retirar uma especie de corte no lado esquerdo
		STA $2001
	Done_Carregar_Estado_Play:


	;;;;Carregar STATE_GAMEOVER;;;;;;
	CMP #STATE_GAMEOVER
	BNE Done_Carregar_Estado_GameOver

		;alterar tipo background que sera carregado
		LDA #$03;game over
		STA tipo_background

		;e necessario resetar a ppu para que o novo background carrege normalmente
		LDA #$00
		STA $2000
		STA $2001

		JSR LoadBackground

		;ativar PPU novamente
		LDA #%10011000   	;habilita NMI, define a Pattern Table do background e sprite como 1
		STA $2000

		LDA #%00011110   	;habilitar sprites, background e retirar uma especie de corte no lado esquerdo
		STA $2001
	Done_Carregar_Estado_GameOver:
	

	RTS;voltar de onde foi chamado

;////////////////////////////
;//// Rotinas do Titulo /////
;////////////////////////////

;;;;;;;;
;Mover Marcador de opcoes
Title_Menu:
	LDA controle1	

	;Apertar Baixo
	CMP #%00000100
	BNE Title_Done_Down
		LDA #$01
		STA marcador;definir como 2 jogadores

		LDA #176
		STA marcador_pos_y;aletrar posicao Y

	Title_Done_Down:

	;Apertar Cima
	CMP #%00001000
	BNE Title_Done_Up
		LDA #$00
		STA marcador;definir como 1 jogador

		LDA #160
		STA marcador_pos_y;alterar posicao Y
		
	Title_Done_Up:

	;Apertar A
	CMP #%10000000
	BNE Title_Soltar_Botao_A
		
		;verificar se ja esta sendo apertado
		LDX estado_botao
		CPX #$01
		BEQ Title_Done_A ;se ja tiver apertando, pular o codigo abaixo ;isso evita de quando o jogo der reset ja selecionar uma opcao sozinho

		;apertar
		LDA #$01
		STA estado_botao

		;Altera jogo para outro estado, indo para a partida
		LDX #STATE_PLAY
		STX gamestate

		JSR Carregar_Novo_Estado

		RTS

	Title_Soltar_Botao_A:
		;Se nao estiver apertando soltar o botao
		LDA #$00
		STA estado_botao
		
	Title_Done_A:

	RTS; voltar para 'Engine_Title'

;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;
;Desenha o marcador de opcoes
Title_DrawMarcador:
	
	LDX #$00
	
	;posicao Y
	LDA marcador_pos_y
	STA $0200, X
	INX

	;numero do tile
	LDA #$D7
	STA $0200, X
	INX

	;informacoes bit a bit
	LDA #%00000011 ;paleta 3
	STA $0200, X
	INX

	;posixao X
	LDA #64
	STA $0200, X
	INX
	
	RTS; voltar para 'Engine_Title'

;;;;;;;;;;;;;;;;;;;;;;;

;////////////////////////////
;///// Rotinas do Play //////
;////////////////////////////

;movimentar bola
MoverBola:
	;mover verticalmente
	checar_eixo_X:
		LDA #$00
		
		CMP ball_dir_x
		BEQ mover_bola_para_esquerda	;Se for esquerda pular para o codigo, se for direita executa o codigo abaixo

		mover_bola_para_direita:
			LDA ball_x 			;A = ball_x
			CLC
			ADC ballspeed_x		;A = A + velocidadeX
			STA ball_x  		;ball_x = A
			
			JMP checar_eixo_Y	;isso é usado para pular o codigo abaixo

		mover_bola_para_esquerda:
			LDA ball_x 			;A = ball_x
			SEC
			SBC ballspeed_x		;A = A - velocidadeX
			STA ball_x 			;ball_x = A

			JMP checar_eixo_Y


	;mover horizontalmente
	checar_eixo_Y:
		LDA #$00
		
		CMP ball_dir_y
		BEQ mover_bola_para_cima	;Se for cima pular para o codigo, se for baixo executa o codigo abaixo

		mover_bola_para_baixo:
			LDA ball_y 			;A = ball_y
			CLC
			ADC ballspeed_y		;A = A + velocidadeY
			STA ball_y 			;ball_y = A
			
			RTS					;isso é usado para pular o codigo abaixo

		mover_bola_para_cima:
			LDA ball_y 			;A = ball_y
			SEC
			SBC ballspeed_y		;A = A - velocidadeY
			STA ball_y  		;ball_y = A
			
	RTS;voltar para 'Engine_Play'


;;;;;;;;;;;;;;;;;;;;;;;

;////////////////////////////////
;///// Rotinas do GameOver //////
;////////////////////////////////

;espera apertar A para voltar ao titulo
GameOver_Continuar:

	LDA controle1

	;Apertar A
	CMP #%10000000
	BNE GameOver_Done_A

		;Precionar botao
		LDA #$01
		STA estado_botao
		
		;Reiniciar o jogo, para reiniciar os sprites e voltar na tela de titulo
		JMP RESET
		
	GameOver_Done_A:
	
	RTS ;voltar para Engine GameOver


;;;;;;;;;;;;;
;Desenha o vencedor
GameOver_Draw:
	
	LDX #$50; comecar a desenhar em um valor alto para nao sobreescrever os outros sprites
	
	;posicao Y
	LDA #103
	STA $0200, X
	INX

	;numero do tile
	LDA vencedor
	STA $0200, X
	INX

	;informacoes bit a bit
	LDA #%00000000 ;paleta 3
	STA $0200, X
	INX

	;posixao X
	LDA #128
	STA $0200, X
	INX
	
	RTS; voltar para 'Engine_Title'


;//////////////////////////
;//////////////////////////
	

;;;;;;;;;;;;;;;;;;
;;Tratar colisoes
ChecarColisao_Bola:

	;;;Colisoes com a tela

	;Lado Esquerdo
	LDA ball_x

	CMP #WALL_LEFT
	BCS EsquerdaDone;if ball_x > Limite, entao pular o codigo
		;Jogador 2 marca ponto sobre o jogador 1
		LDA score2
		CLC
		ADC #$01 			;score ++
		STA score2
		
		JMP Checar_por_vencedor_2;verifica se player 2 venceu

	EsquerdaDone:


	;Lado Direito
	LDA ball_x

	CMP #WALL_RIGTH
	BCC DireitaDone;if ball_x < Limite, entao pular o codigo
		;Jogador 1 marca ponto sobre o jogador 2
		LDA score1
		CLC
		ADC #$01 			;score ++
		STA score1
		
		JMP Checar_por_vencedor_1;verifica se player 1 venceu

	DireitaDone:	


	;Cima
	LDA ball_y

	CMP #WALL_TOP
	BCS CimaDone 		;if ball_y > Limite, entao pular o codigo
		LDA #$01
		STA ball_dir_y; inverter direcao do movimento vertical
	CimaDone:
	
	;Baixo
	LDA ball_y

	CMP #WALL_BOTTOM
	BCC BaixoDone		;se ball_y < Limite, entao pular o codigo
		LDA #$00
		STA ball_dir_y; inverter direcao do movimento vertical
	BaixoDone:


	;;;Colisao com o jogador 1
	
	;salvar as propriedades da bola na variavel de checagem de colisao
	LDA ball_x
	STA colisao_x_1
	LDA ball_y
	STA colisao_y_1
	LDA #08
	STA colisao_w_1
	STA colisao_h_1

	;agora salvar as propriedades do jogador
	LDA player1_x
	STA colisao_x_2
	LDA player1_y
	STA colisao_y_2
	LDA #08
	STA colisao_w_2
	LDA #40 		;8 * 5
	STA colisao_h_2

	
	JSR Checar_Colisao;Checar colisao!!!

	LDA colisao_return;apos a checagem a rotina 'Checar Colisao' salva um valor na variavel 'colisao_return', 0 = SEM colisao, 1 = COM colisao
	CMP #$01
	BNE sem_colisao_com_player1;se nao houver colisao pular o codigo abaixo

		;inverter eixo de movimento X
		LDA ball_dir_x		;A = dir_x
		CMP #$00			;comparar com 00
		BEQ set1_dir_x_01	;se ja for 0 transformar em 1, caso contrario trasformar em 0
		set1_dir_x_00:
			LDA #$00
			STA ball_dir_x

			JMP invert_eixo_Done1	;usado para pular a instrucao abaixo

		set1_dir_x_01:
			LDA #$01
			STA ball_dir_x

		invert_eixo_Done1:

		
		;reposicionar o valor X da bola ao lado do player para evitar bugs
		LDA player1_x
		STA math_x 		;math_x = player_x
		LDA #08
		STA math_y		;math_y = player_w
		JSR Somar 		;math_r = pl_x + pl_w

		LDA math_r
		STA ball_x

		;aumentar contador de rebatidas
		LDA rebatida
		CLC
		ADC #01
		STA rebatida
	sem_colisao_com_player1:


	;;;Colisao com o jogador 2

	;salvar apenas as propriedades do jogador 2 pois a bola ja est salva
	LDA player2_x
	STA colisao_x_2
	LDA player2_y
	STA colisao_y_2

	JSR Checar_Colisao;Checar colisao!!!

	LDA colisao_return
	CMP #$01
	BNE sem_colisao_com_player2;se nao houver colisao pular o codigo abaixo

		;inverter eixo de movimento X
		LDA ball_dir_x		;A = dir_y
		CMP #$00			;comparar com 00
		BEQ set2_dir_x_01	;se ja for 0 transformar em 1, caso contrario trasformar em 0
		set2_dir_x_00:
			LDA #$00
			STA ball_dir_x

			JMP invert_eixo_Done2	;usado para pular instrucao abaixo

		set2_dir_x_01:
			LDA #$01
			STA ball_dir_x

		invert_eixo_Done2:

		
		;alterar posicao X da bola para evitar bugs
		LDA player2_x
		SEC
		SBC #08
		STA ball_x

		
		;aumentar contador de rebatida
		LDA rebatida
		CLC
		ADC #01
		STA rebatida
	sem_colisao_com_player2:


	
	;;;Aumentar velocidade a cada 2 rebatidas
	LDA rebatida
	CMP #$02					;comparar com o valor 2
	BNE Done_aumentar_ball_vel	;se nao for igual pular o codigo abaixo
		LDA #$00
		STA rebatida 			;resetar contador

		LDA ballspeed_y
		CLC
		ADC #$01
		STA ballspeed_y 		;aumentar em 1 o valor de Y

		LDA ballspeed_x
		CLC
		ADC #$01
		STA ballspeed_x			;aumentar em 1 o valor de X

		;Checar por limite
		CMP #04					;comparar o A (speed_x) com 4
		BCC Done_Limite_velocidade_bola ;se tiver um valor menor pular esse codigo
			LDA #$04
			STA ballspeed_x
			LDA #$03
			STA ballspeed_y

		Done_Limite_velocidade_bola:

	Done_aumentar_ball_vel:

	RTS;retornar para 'Engine_Play'


	;Checar se player 1 venceu
	Checar_por_vencedor_1:
		LDA score1;A = score

		CMP #10;compara com 10
		BNE done_vencedor_1 ;se nao fez 10 pontos pular esse codigo
			LDA #$01
			STA vencedor;gravar o valor do sprite '1'

			LDA #STATE_GAMEOVER
			STA gamestate

			JSR Carregar_Novo_Estado

			RTS

		done_vencedor_1:
		JSR ResetarBola 	;voltar bola na posicao original
	RTS; voltar para 'Engine_Play'

	;Checar se player 2 venceu
	Checar_por_vencedor_2:
		LDA score2;A = score

		CMP #10;compara com 10
		BNE done_vencedor_2 ;se nao fez 10 pontos pular esse codigo
			LDA #$02
			STA vencedor;gravar o valor do sprite '2'

			LDA #STATE_GAMEOVER
			STA gamestate

			JSR Carregar_Novo_Estado

			RTS

		done_vencedor_2:
		JSR ResetarBola 	;voltar bola na posicao original
	RTS;voltar para 'Engine_Play'


;;;;;;;;;;;;;;;;;;
;;Desenhar a pontuacao
DrawScore:
	LDX #$00

	;;;;;;;;;;;;;Score 1
	
	;;;;;;;Digito 1
	;posY
	LDA #24
	STA $0200, X
	INX

	;numero do tile
	LDA score1
	;se o score chegar em 10 carrega o sprite '1', se nao fazer isso o sprite carregado sera o 'A'
	CMP #10
	BNE voltar_para_1_player1; se ainda nao estiver 10 pontos pular o codigo abaixo
		LDA #$01; carregar numero 1
	voltar_para_1_player1:

	STA $0200, X
	INX

	;bit-a-bit
	LDA #%00000001 ;paleta 1
	STA $0200, X
	INX

	;pos X
	LDA #50
	STA $0200, X
	INX

	;;;;;;;Digito 2
	;posY
	LDA #24
	STA $0200, X
	INX

	;numero do tile
	LDA score1
	CMP #10
	BNE nao_desenhar_digito_2_player1; se ainda nao estiver 10 pontos pular o codigo abaixo
		LDA #$00; carregar digito 2
		JMP done_desenhar_digito_2_player1; pular o codigo abaixo
	nao_desenhar_digito_2_player1:
	LDA #$FF; carregar tile em branco

	done_desenhar_digito_2_player1:

	STA $0200, X
	INX

	;bit-a-bit
	LDA #%00000001 ;paleta 1
	STA $0200, X
	INX

	;pos X
	LDA #58
	STA $0200, X
	INX	


	;;;;;;;;;;;;;Score 2

	;;;;;;;Digito 1
	;posY
	LDA #24
	STA $0200, X
	INX

	;numero do tile
	LDA score2
	;se o score chegar em 10 carrega o sprite '1', se nao fazer isso o sprite carregado sera o 'A'
	CMP #10
	BNE voltar_para_1_player2; se ainda nao estiver 10 pontos pular o codigo abaixo
		LDA #$01; carregar numero 1
	voltar_para_1_player2:

	STA $0200, X
	INX

	;bit-a-bit
	LDA #%00000010 ;paleta 2
	STA $0200, X
	INX

	;pos X
	LDA #200
	STA $0200, X
	INX

	;;;;;;;Digito 2
	;posY
	LDA #24
	STA $0200, X
	INX

	;numero do tile
	LDA score2
	CMP #10
	BNE nao_desenhar_digito_2_player2; se ainda nao estiver 10 pontos pular o codigo abaixo
		LDA #$00; carregar digito 2
		JMP done_desenhar_digito_2_player2; pular o codigo abaixo
	nao_desenhar_digito_2_player2:
	LDA #$FF; carregar tile em branco

	done_desenhar_digito_2_player2:

	STA $0200, X
	INX

	;bit-a-bit
	LDA #%00000010 ;paleta 1
	STA $0200, X
	INX

	;pos X
	LDA #208
	STA $0200, X
	INX


	RTS; voltar


;;;;;;;;;;;;;;;;;;
;;Desenhar a bola e os personagens
DrawSprites:
	LDX #$10	;(16 em decimal) comeca contador no ultimo valor dos sprites uzados em 'DrawScore'
	
	;;Bola
	;posicao Y
	LDA ball_y
	STA $0200, X
	INX

	;numero do tile
	LDA #$40
	STA $0200, X
	INX

	;bit-a-bit
	LDA #%00000000 ;paleta 0
	STA $0200, X
	INX

	;posixao X
	LDA ball_x
	STA $0200, X
	INX


;;Player 1

	LDY #00					;Y = 0
Loop_DrawPlayer1:			;a cada loop desenha um sprite
	
	;aumentar em 8 a posicao do tile
	STY math_x		;math_x = Y
	LDA #08
	STA math_y		;math_y = 8	
	JSR Multiplicar ;math_r = Y * 8

	;Somar com a posicao do player
	LDA math_r		
	STA math_x		;math_x = math_r
	LDA player1_y
	STA math_y		;math_y = player_y
	JSR Somar 		;math_r = soma de X e Y

	;posicao Y
	LDA math_r
	STA $0200, X
	INX

	;id do tile
	LDA #$41
	STA $0200, X
	INX

	;bit-a-bit
	LDA #%00000001 ;paleta 1
	STA $0200, X
	INX

	;posicao X
	LDA player1_x
	STA $0200, X
	INX

	INY					;Y ++
	CPY #05				;desenhar 4 vezes o tile
	BNE Loop_DrawPlayer1


;;Player 2

	LDY #00					;Y = 0
Loop_DrawPlayer2:			;a cada loop desenha um sprite
	
	;aumentar em 8 a posicao do tile
	STY math_x		;math_x = Y
	LDA #08
	STA math_y		;math_y = 8	
	JSR Multiplicar 	;math_r = Y * 8

	;Somar com a posicao do player
	LDA math_r		
	STA math_x		;math_x = math_r
	LDA player2_y
	STA math_y		;math_y = player_y
	JSR Somar 		;math_r = soma de X e Y

	;posicao Y
	LDA math_r
	STA $0200, X
	INX

	;id do tile
	LDA #$41
	STA $0200, X
	INX

	;bit-a-bit
	LDA #%00000010 ;paleta 2
	STA $0200, X
	INX

	;posicao X
	LDA player2_x
	STA $0200, X
	INX

	INY					;Y ++
	CPY #05				;desenhar 4 vezes o tile
	BNE Loop_DrawPlayer2
	

	RTS 	;retornar para 'Engine_Play'


;;;;;;;;;;;;;;;;;
;;Mover Jogador 1

MoverPlayer_1:
	
	LDA controle1 ;A = controle
	

	;Apertando Baixo
	CMP #%00000100
	BNE Done_Down_1
		LDA player1_y 			;A = player_y
		CLC
		ADC player_speed		;A = A + velocidedaY
		STA player1_y 			;player_y = A

		;;Limitar posicao

		LDA player1_y

		CMP #WALL_BOTTOM - 24
		BCC Done_Down_1 		;if player_y > Limite de baixo, entao definir a posicao no limite, se nao pular o codigo
			LDA #WALL_BOTTOM - 24
			STA player1_y
	Done_Down_1:

	
	;Apertando Cima
	CMP #%00001000
	BNE Done_Up_1
		LDA player1_y 			;A = player_y
		SEC
		SBC player_speed		;A = A - velocidedaY
		STA player1_y 			;player_y = A

		;;Limitar posicao

		LDA player1_y

		CMP #WALL_TOP
		BCS Done_Up_1 			;if player_y < Limite de cima, entao definir a posicao no limite, se nao pular o codigo
			LDA #WALL_TOP
			STA player1_y
	Done_Up_1:


	RTS; voltar de onde veio


;;;;;;;;;;;;;;;;;
;;Mover Jogador 2

MoverPlayer_2:
	
	LDA marcador
	CMP #$01 ;comparar se estiver em modo 2 jogadores
	BNE mover_player_2_com_ia     ;se nao estiver em 2 jogadores pular o bloco abaixo
	
	LDA controle2;A = controle 2
	

	;Apertando Baixo
	CMP #%00000100
	BNE Done_Down_2
		LDA player2_y 			;A = player_y
		CLC
		ADC player_speed		;A = A + velocidedaY
		STA player2_y 			;player_y = A

		;;Limitar posicao

		LDA player2_y

		CMP #WALL_BOTTOM - 24
		BCC Done_Down_2 		;if player_y > Limite de baixo, entao definir a posicao no limite, se nao pular o codigo
			LDA #WALL_BOTTOM - 24
			STA player2_y
	Done_Down_2:

	
	;Apertando Cima
	CMP #%00001000
	BNE Done_Up_2
		LDA player2_y 			;A = player_y
		SEC
		SBC player_speed		;A = A - velocidedaY
		STA player2_y 			;player_y = A

		;;Limitar posicao

		LDA player2_y

		CMP #WALL_TOP
		BCS Done_Up_2 		;if player_y < Limite de cima, entao definir a posicao no limite, se nao pular o codigo
			LDA #WALL_TOP
			STA player2_y
	Done_Up_2:

	RTS; voltar de onde veio
	
	;;;;Mover pela IA
	;apenas segue a bola posicao da bola, impossivel de perder
	mover_player_2_com_ia:
		LDX ball_y		;X = bola_y

		STX player2_y	;player_y = bola_y
		
		;Checa se nao vai ultrapassar o limite de baixo
		CPX #WALL_BOTTOM - 24
		BCC Done_Down_IA 		;if player_y > Limite de baixo, entao definir a posicao no limite, se nao pular o codigo
			LDX #WALL_BOTTOM - 24
			STX player2_y

		Done_Down_IA:		
	
	RTS; voltar de onde veio

;;;;;;;;;;;;;;;;;;;;;;


;///////////////////////////
;////Sub rotinas gerias ////
;///////////////////////////

;;;;;;;;;;;;;;;;;
;Resetar posicao da bola
ResetarBola:

	;posicao - no meio da tela
	LDA #(256 / 2) - 4
	STA ball_x
	LDA #(240 / 2) - 8
	STA ball_y

	;velocidade inicial
	LDA #$01
	STA ballspeed_x
	LDA #$02
	STA ballspeed_y

	;zerar rebatida
	LDA #$00
	STA rebatida
	

	RTS;voltar de onde foi chamado


;;;;;;;;;;;;;;;;;;;
;Ler controles

LerControle_1:
	LDA #$01
	STA $4016
	LDA #$00
	STA $4016

	LDX #$08
Loop_LerControle_1:
	LDA $4016
	LSR A    		;bit0 -> Carry
	ROL controle1 	;bit0 <- Carry 
	DEX
	BNE Loop_LerControle_1
	RTS

	;;;;;Ao final do loop a variavel 'controle1' ficara nesse modelo:
	;;Bit: 	    7  6    5      4     3   2      1    0 
	;;Controle: A  B  select start  up  down  left right
	;;;;;

;;;;;;

LerControle_2:
	LDA #$01
	STA $4017
	LDA #$00
	STA $4017

	LDX #$08
Loop_LerControle_2:
	LDA $4017
	LSR A
	ROL controle2
	DEX
	BNE Loop_LerControle_2
	RTS


;/////////////////////////////////
;///// Carregar Background ///////
;/////////////////////////////////

LoadBackground:

	;configurar o ppu para receber o background
	LDA $2002
	LDA #$20
	STA $2006
	LDA #$00
	STA $2006


	;;;escolher background sera carregado
	LDA tipo_background
	

	CMP #$01 ; titulo
	BNE Done_Banckground_Tipo_1
		;Salvar o endereco LOW e HIGH byte da tabela na memoria
		LDA #LOW(Background_Titulo)	
		STA Low_Byte_Background			;contem #$00
		LDA #HIGH(Background_Titulo)
		STA High_Byte_Background		;contem #$EE
	Done_Banckground_Tipo_1:
	
	CMP #$02 ; campo
	BNE Done_Banckground_Tipo_2
		;Salvar o endereco LOW e HIGH byte da tabela na memoria
		LDA #LOW(Background_Campo)	
		STA Low_Byte_Background			;contem #$00
		LDA #HIGH(Background_Campo)
		STA High_Byte_Background		;contem #$EE
	Done_Banckground_Tipo_2:

	CMP #$03 ; game over
	BNE Done_Banckground_Tipo_3
		;Salvar o endereco LOW e HIGH byte da tabela na memoria
		LDA #LOW(Background_GameOver)	
		STA Low_Byte_Background			;contem #$00
		LDA #HIGH(Background_GameOver)
		STA High_Byte_Background		;contem #$EE
	Done_Banckground_Tipo_3:	

	;;;;;;;;
	;;;;;; * Nos comentarios estao sendo usados valores ilustrativos apenas como exemplos
	;;;;;;;;


	LDY #$00				;Y = 0
	STY valor_temporario	;$001C = 0, sera usado para compararacao
Loop_LoadBackground:

	LDA [Low_Byte_Background], Y 	;Essa instrucao retorna o valor (8 bytes) dentro de uma posicao da memoria (16 bytes)
									;para isso ela:
									; - Le o valor entre colchetes. Exemplo: $001A = #$00
									; - Depois ela le o valor da memoria ao lado. Exemplo: $001B = #$E0
									; - Como a CPU e "little-endian" o  valor e juntado de forma contraria.
									;Nesse exemplo ficara: $E000
									; - Agora incrementa com o valor de Y. $E000 + Y(3) = $E003
									; Por fim salva no registrador "A" o valor contido em $E003


	;;Checar se o background e do tipo vazio
	LDX tipo_background
	CPX #$00
	BNE Done_none_background 	;se for diferente pular esse codigo
		LDA #$FF				;carrega um tile vazio no A
	Done_none_background:
	STA $2007			;grava o valor na PPU

	CPY #$FF 			;compara se esse e o ultimo valor
	
	INY					;Y ++ , usado depois da comparacao para que o endereco $FF seja lido

	




	BNE done_ler_proximo_bloco 	;Se ainda nao for o ultimo endereco, pular o codigo abaixo
								;sempre que o Y = FF, sera acrescentado 1 byte no HIGH byte do endereco que esta sendo lido o background
								;isso e necessario para que seja lido todo o arquivo
										;;; * Exemplo na primeira vez que esse codigo sera executado:
		LDX High_Byte_Background 		;X = $001B = $#E0
		INX 							;X = $#E1
		STX High_Byte_Background 		;$001B = X

		LDY #$00 				;Y = 0

		LDX valor_temporario
		INX
		STX valor_temporario	;acrescenta +1 no endereco 001C, usado para checar se ja leu todo o arquivo.
								;esse bloco deve ser executado 4 vezes. Quando gravar o valor $#05 em $001C que dizer que a leitura ja foi concluida

	done_ler_proximo_bloco:
	

	LDA valor_temporario
	CMP #$05			;compara se no ja leu 4 vezes o background

	BNE Loop_LoadBackground ;se nao leu tudo continuar lendo


	;;;;;;;;;;
	;;Chama a rotina para carregar os atributos do background
	JSR LoadAtributos


	RTS; voltar de onde foi chamado

;;;;;;;;;;;;
;Carregar Atributos do Background
LoadAtributos:
	LDA $2002
	LDA #$23
	STA $2006
	LDA #$C0
	STA $2006


	;Como essa rotina e chamada logo apos o background precisa retornar 1 byte do valor HIGH pois no final do loop do background o valor avança 1 byte a mais
	LDA High_Byte_Background
	SEI
	SBC #$01
	STA High_Byte_Background


	LDY #$00
Loop_LoadAtributos:
	LDA [Low_Byte_Background], Y
	STA $2007
	
	CPY #64
	INY
	BNE Loop_LoadAtributos

	RTS; voltar para 'LoadBackground'




;///////////////////////
;///// Matematica //////
;///////////////////////

;;salva os registradores em variaveis (usado antes de uma conta)
_Salvar_Registradores:
	STA registrador_a
	STX registrador_x
	STY registrador_y

	RTS

;;carrega os valores salvos dos registradores (usado depois de uma conta)
_Carregar_Registradores:
	LDA registrador_a
	LDX registrador_x
	LDY registrador_y

	RTS
	

;Soma os valores das variaveis matematicas e retorna o valor na variavel "math_r"
Somar:
	JSR _Salvar_Registradores


	LDA math_x 			;A = math_x
	
	CLC
	ADC math_y			;A = A + math_y
	
	STA math_r 			;math_r = A

	JSR _Carregar_Registradores

	RTS

;;;;;;;;

;Multiplicacao entre variaveis X e Y, retorna o valor em "math_r"

Multiplicar:

	JSR _Salvar_Registradores

	LDA #$00			;A = 0
	STA math_r			;resultado = 0

	LDX math_x			;pega o valor a ser multiplicado
	LDY math_y			;pega a quantidade que sera multiplicado	


	;;verificar se algum valor e igual a 0
	CPX #00
	BEQ _fim_multiplicacao
	CPY #00
	BEQ _fim_multiplicacao
	
	
	_Loop_Multiplicao:
		CLC
		ADC	math_x		;somar o valor ao A

		DEY 		 	;diminuir quantidade de vezes

		CPY #00
		BNE _Loop_Multiplicao 	;Enquando nao somar tudo continuar

	
	_fim_multiplicacao:
		STA math_r			;salvar resultado
		JSR _Carregar_Registradores
		RTS

;;;;;;;;;;;;;;;;;;

;/////////////////////////
;/////// Colisao: ////////

;Checa a colisao entre as variaveis de colisao 1 e 2.
;se houver colisao a rotina escreve na variavel colisao_return o valor "01", caso nao tenha escreve "00"
Checar_Colisao:
	
	JSR _Salvar_Registradores

	;;;eixo X
	;se o canto esquerdo 2 + o canto direito 2 for menor que o canto esquerdo 1
	LDA colisao_x_2
	STA math_x			;math_x = x2
	LDA colisao_w_2
	STA math_y			;math_y = w2
	JSR Somar 			;math_r = x2 + w2

	LDA math_r
	CMP colisao_x_1
	BCC _sem_colisao

	;se o canto esquerdo 2 for maior que o canto esquerdo 1 + canto direito 1	

	LDA colisao_x_1
	STA math_x			;math_x = x1
	LDA colisao_w_1
	STA math_y			;math_y = w1
	JSR Somar 			;math_r = x1 + w1

	LDA colisao_x_2
	CMP math_r
	BCS _sem_colisao

	;;;eixo Y
	;se canto de cima 2 + canto de baixo 2 for menor que o canto de cima 1

	LDA colisao_y_2
	STA math_x			;math_x = y2
	LDA colisao_h_2
	STA math_y 			;math_y = h2
	JSR Somar 			;math_r = y2 + h2

	LDA math_r
	CMP colisao_y_1
	BCC _sem_colisao

	;se o canto de cima 2 for maior que o canto de cima 1 + canto de baixo 1
	
	LDA colisao_y_1
	STA math_x			;math_x = y1
	LDA colisao_h_1
	STA math_y			;math_y = h1
	JSR Somar 			;math_r = y1 + h1

	LDA colisao_y_2
	CMP math_r
	BCS _sem_colisao


	_com_colisao:
		LDA #$01
		STA colisao_return
		JSR _Carregar_Registradores
		RTS

	_sem_colisao:
		LDA #$00
		STA colisao_return
		JSR _Carregar_Registradores
		RTS
	


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.bank 1

	.org $E000

;os valores hexadecimais podem ser carregados com ".db" ou inseridos em um arquivo e carregado com "incbin".
;para carregar use LDA Paleta, X   ; onde X e um numero que sera acresentado ao endereco
Background_Titulo:
	.incbin "data/background_titulo.nam"

Background_Campo:
	.incbin "data/background_campo.nam"

Background_GameOver:
	.incbin "data/background_gameover.nam"

Paleta:
	.incbin "data/paleta.dat"
	

	.org $FFFA     ;os 3 vetores devem comecar aqui

	.dw NMI        ;o NMI representa uma atualizacao do frame, quando ocorre o processador pula para essa instrucao
	.dw RESET      ;quando houver um reset no sistema o processador ira pulara para essa rotina
	.dw 0          ;representa o IRQ, nao usado


;;;;;;;;;;;;;;;;;;;;;;;;	
	.bank 2
	.org $0000
	.incbin "data/pong.chr";arquivo dos sprites