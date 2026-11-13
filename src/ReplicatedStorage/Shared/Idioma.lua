--!nonstrict
--[[
	Idioma (compartido): español o inglés según el idioma que el jugador eligió en la configuración de Roblox
	(Player.LocaleId: "es-es", "es-mx", "en-us", etc.). Si empieza con "es" se juega en español; con cualquier otro, en inglés.

	El juego está escrito en español (los textos viajan así del servidor al cliente), y el cliente traduce lo que va a
	mostrar con Idioma.t(texto): primero busca el texto exacto en EN, y si no está, prueba los PATRONES (textos con números
	o nombres adentro, como "Anomalía registrada (2/5)."). Lo que no tiene traducción se muestra tal cual.
	  Idioma.actual() -> "es" | "en"
	  Idioma.t(texto) -> texto traducido (o el mismo si no hace falta o no se conoce)
	  Idioma.enIngles() -> boolean
	  Idioma.sinTraducir() -> { [texto] = veces }   -- para depurar: textos en español que se mostraron sin traducción
	Config.Idioma.Forzar = "en" | "es" fuerza un idioma (pruebas).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local Idioma = {}

local sinTraducir = {}
shared.IdiomaSinTraducir = sinTraducir -- (depuración: se puede leer desde cualquier script del cliente)

function Idioma.actual(): string
	local forzado = Config.Idioma and Config.Idioma.Forzar
	if forzado then
		return forzado
	end
	if RunService:IsClient() then
		local jugador = Players.LocalPlayer
		local locale = jugador and jugador.LocaleId or "es-es"
		return string.lower(string.sub(locale, 1, 2)) == "es" and "es" or "en"
	end
	return "es"
end

function Idioma.enIngles(): boolean
	return Idioma.actual() == "en"
end

-- ===== Textos exactos =====
local EN = {
	-- Géneros y pasillos
	["ACCIÓN"] = "ACTION", ["ACCION"] = "ACTION", ["TERROR"] = "HORROR", ["COMEDIA"] = "COMEDY", ["DRAMA"] = "DRAMA", ["INFANTIL"] = "KIDS",
	-- Títulos de las películas
	["Puño de Acero III"] = "Fist of Steel III", ["Operación Cóndor Negro"] = "Operation Black Condor",
	["El Último Marine"] = "The Last Marine", ["Dinamita en Retiro"] = "Dynamite at Retiro",
	["La Casa del Lago Seco"] = "The House by the Dry Lake", ["Noche de Muñecos"] = "Night of the Dolls",
	["El Sótano de Don Aldo"] = "Don Aldo's Basement", ["Pesadilla en Villa Ballester"] = "Nightmare in Villa Ballester",
	["Los Vecinos del 4°B"] = "The Neighbors of 4B", ["Mi Suegra es Marciana"] = "My Mother-in-Law Is a Martian",
	["Tango y Cachetadas"] = "Tango and Slaps", ["Cuidado con el Gerente"] = "Beware of the Manager",
	["Cartas desde Rosario"] = "Letters from Rosario", ["Lluvia en Mataderos"] = "Rain in Mataderos",
	["El Silencio de Marta"] = "Marta's Silence", ["Un Verano Sin Vos"] = "A Summer Without You",
	["Los Aventureros del Delta"] = "The Delta Adventurers", ["Pipo y la Luna"] = "Pipo and the Moon",
	["El Dragón de Papel"] = "The Paper Dragon", ["Mini Detectives"] = "Mini Detectives",
	-- Títulos extraños (anomalías)
	["NO MIRES ATRÁS"] = "DON'T LOOK BACK", ["SOCIO 0000"] = "MEMBER 0000", ["VOLVÉ"] = "COME BACK", ["MIRAME"] = "LOOK AT ME",
	["ESTÁS EN LA CINTA"] = "YOU'RE ON THE TAPE", ["NO REBOBINES"] = "DON'T REWIND", ["ÉL YA ESTÁ ADENTRO"] = "HE'S ALREADY INSIDE",
	-- Clientes
	["Cliente"] = "Customer",
	["Vengo a devolver esto. Perdón por la demora."] = "I'm here to return this. Sorry for the delay.",
	["Te traigo esto de vuelta, ya la vimos."] = "Bringing this back, we've already seen it.",
	["Se trabó un poco... creo que quedó arrugada."] = "It got stuck a little... I think it's crinkled.",
	["Ojo que esta se comió la cinta. Perdoná."] = "Careful, this one ate the tape. Sorry.",
	["Gracias, che. Hasta mañana."] = "Thanks, man. See you tomorrow.",
	["Buenísimo. ¡Que andes bien!"] = "Great. Take care!",
	["Qué lento... mejor me voy."] = "So slow... I'd better go.",
	["Uf, vuelvo otro día."] = "Ugh, I'll come back another day.",
	["Vengo por mi cinta. La del socio cero."] = "I'm here for my tape. Member zero's.",
	["No hay nadie en el mostrador."] = "There's nobody at the counter.",
	["Espera algo: la cinta sin etiqueta. Tenés que tenerla en la mano."] = "He's waiting for something: the unlabeled tape. You need to be holding it.",
	["Este no se va a ir así nomás."] = "This one won't just leave.",
	["Ya veo. Nos vemos pronto."] = "I see. See you soon.",
	["El cliente se fue sin decir nada más."] = "The customer left without another word.",
	["¿Cómo que no? Qué mala atención."] = "What do you mean no? Terrible service.",
	["Rechazaste a un cliente normal."] = "You turned away a normal customer.",
	-- Notas de Darío
	["No repongas ninguna cinta cuyo título no pegue con el género. Ninguna."] = "Don't restock any tape whose title doesn't fit the genre. None.",
	["Pasadas las 2:00, el teléfono del depósito NO se atiende. No importa quién llame."] = "After 2:00, DON'T answer the storeroom phone. It doesn't matter who calls.",
	["A las 3:00 apagá la tele del mostrador. Le hace mal a la cinta."] = "At 3:00, turn off the counter TV. It's bad for the tape.",
	["Ningún socio tiene cuatro ceros. Si alguien lo dice, no lo atiendas."] = "No member has four zeros. If someone says so, don't serve them.",
	["Atendé SIEMPRE a todos los clientes. Sin excepciones. Don Ernesto lo pide."] = "ALWAYS serve every customer. No exceptions. Don Ernesto's orders.",
	["La cinta se va de dos maneras: se devuelve o se le graba encima. (R en la videocasetera)"] = "The tape leaves in two ways: you return it or you record over it. (R at the VCR)",
	["Mirá la cinta hasta el final. No pasa nada, te lo juro."] = "Watch the tape to the end. Nothing happens, I swear.",
	-- Teléfono
	["Don Ernesto (por teléfono)"] = "Don Ernesto (on the phone)",
	["¿Hola? ¿Ya llegaste? Soy Don Ernesto, el dueño. Te llamo rápido porque esta noche no puedo ir."] = "Hello? Have you arrived? It's Don Ernesto, the owner. I'm calling quickly because I can't come tonight.",
	["Esto es lo que tenés que hacer. Cuando entre un cliente, andá al mostrador y apretá E para atenderlo."] = "Here's what you have to do. When a customer comes in, go to the counter and press E to serve them.",
	["Si quiere alquilar, te dice qué género busca. Andá a esa góndola, apretá E para sacar un casete y llevásselo al mostrador."] = "If they want to rent, they'll tell you which genre. Go to that shelf, press E to take a tape and bring it to the counter.",
	["Si viene a devolver, deja la cinta en el mostrador. Agarrala con E, rebobinala en la videocasetera (mantené E) y ponela en su góndola."] = "If they're returning one, they leave the tape on the counter. Grab it with E, rewind it in the VCR (hold E) and put it on its shelf.",
	["Si una cinta está arrugada, no se rebobina: va a la caja de dañadas. Lo mismo con las que caen por el buzón."] = "If a tape is crinkled, don't rewind it: it goes in the damaged box. Same for the ones that drop through the mail slot.",
	["Cuando no haya clientes, hay laburo de limpieza. Las bolsas de basura van al contenedor del patio: puerta del fondo, a la derecha."] = "When there are no customers, there's cleaning to do. Trash bags go to the dumpster in the yard: back door, on the right.",
	["Y si ves una mancha en el piso, agarrá la escoba que está apoyada en el baño y mantené E encima hasta que desaparezca. Lo que no hagas vos, que lo haga tu compañero."] = "And if you see a stain on the floor, grab the broom leaning in the bathroom and hold E on it until it's gone. What you don't do, your teammate will.",
	["Tu ficha de socio está a la izquierda: ahí figura todo lo que falta. Con Tab la mostrás o la ocultás. Y con G soltás lo que tengas en la mano."] = "Your member card is on the left: everything left to do is listed there. Tab shows or hides it. And G drops whatever you're holding.",
	["Si alguna vez la luz se corta, F es la linterna. Y si ves algo fuera de lugar, apuntale y apretá Q. Después hablamos de eso."] = "If the lights ever go out, F is the flashlight. And if you see something out of place, aim at it and press Q. We'll talk about that later.",
	["Hasta las cuatro de la mañana. No me llamen, yo los llamo. Suerte, che."] = "Until four in the morning. Don't call me, I'll call you. Good luck, man.",
	["Soy Ernesto otra vez. Escuchame bien: desde anoche pasan cosas raras en el local."] = "It's Ernesto again. Listen carefully: strange things have been happening in the store since last night.",
	["A veces algo aparece cambiado: un título que no existe, una carátula rara, un objeto fuera de lugar, o una sombra que camina por el techo y las paredes."] = "Sometimes something shows up changed: a title that doesn't exist, a weird cover, an object out of place, or a shadow that walks on the ceiling and the walls.",
	["Eso son anomalías. Cuando veas una, apuntale y apretá Q. Si acertás, queda registrada y el Socio se calma un poco. Si las dejás, se enoja. Y a la que anda por el techo, si no la marcás a tiempo, se te tira encima."] = "Those are anomalies. When you see one, aim at it and press Q. If you're right, it gets logged and the Member calms down a little. If you leave them, he gets angry. And the one that walks on the ceiling, if you do not mark it in time, jumps on you.",
	["En tu ficha, abajo de todo, figura cuántas encontraste. Los cambios en el local los ve cada uno distintos, así que no se los puede copiar al compañero. La que anda por el techo, en cambio, es una sola y la ven todos: si alguien la marca, desaparece para el equipo."] = "At the bottom of your card it shows how many you found. Everyone sees different changes around the store, so you can't copy your teammate's. The one on the ceiling, though, is a single one and everyone sees it: if someone marks it, it disappears for the whole team.",
	["Ojo: la sombra que camina por el techo es una anomalía, no es él. El Socio es otra cosa: cuando lo mirás se arrastra mucho más lento. A ese no se le apunta con la Q: se lo mira y no se le saca la vista de encima."] = "Careful: the shadow that walks on the ceiling is an anomaly, it's not him. The Member is something else: when you look at him he crawls much slower. You don't aim at that one with Q: you look at him and never take your eyes off him.",
	["CONTESTADOR - Don Ernesto"] = "ANSWERING MACHINE - Don Ernesto",
	["Habla Don Ernesto. Las llaves están en el cajón. No me llamen: yo los llamo."] = "This is Don Ernesto. The keys are in the drawer. Don't call me: I'll call you.",
	["Es un turno tranquilo. Rebobinen, repongan y atiendan a los socios."] = "It's a quiet shift. Rewind, restock and serve the members.",
	["Ernesto otra vez. Si llama Darío, no le atiendan. Renunció, ya está."] = "Ernesto again. If Darío calls, don't pick up. He quit, that's it.",
	["Y no toquen nada de lo que dejó pegado en las paredes... bueno, léanlo, nomás."] = "And don't touch anything he left stuck on the walls... well, just read it.",
	["(estática)"] = "(static)",
	["...bienvenido al Videoclub Estrella... turno noche..."] = "...welcome to Star Video Club... night shift...",
	["...ya estás en la cinta..."] = "...you're already on the tape...",
	["No mires hacia atrás."] = "Don't look behind you.",
	["Ya te vi trabajar esta noche. Dejá la cinta donde está."] = "I saw you work tonight. Leave the tape where it is.",
	["Darío"] = "Darío",
	["teléfono del mostrador"] = "counter phone", ["teléfono del depósito"] = "storeroom phone",
	["No está sonando."] = "It isn't ringing.",
	["Atender teléfono"] = "Answer phone",
	["TELÉFONO SONANDO\n[E] atender"] = "PHONE RINGING\n[E] answer",
	-- Finales
	["FINAL 1/3: REBOBINAR"] = "ENDING 1/3: REWIND",
	["Le grabás encima. La imagen se llena de estática y, después, de nada."] = "You record over it. The picture fills with static and then with nothing.",
	["El Socio N° 0000 no vuelve a aparecer."] = "Member No. 0000 never appears again.",
	["A las 22:00 el local abre otra vez. En la ficha del mostrador falta un nombre."] = "At 22:00 the store opens again. A name is missing from the counter file.",
	["Alguien empieza un turno que ya empezó."] = "Someone starts a shift that already started.",
	["FINAL 2/3: DEVOLVER (final verdadero)"] = "ENDING 2/3: RETURN (true ending)",
	["Le devolvés la cinta. El Socio N° 0000 la mira un momento y asiente."] = "You give him back the tape. Member No. 0000 looks at it for a moment and nods.",
	["Cerrás su cuenta. En la ficha aparece, por fin, el nombre que faltaba: DARÍO."] = "You close his account. At last the missing name appears on the card: DARÍO.",
	["Darío fue el primero en encontrar la cinta. No renunció: lo grabaron. Su último turno seguía repitiéndose adentro."] = "Darío was the first to find the tape. He didn't quit: they recorded him. His last shift kept repeating inside.",
	["Ahora el socio cero puede irse. Y Darío con él."] = "Now member zero can leave. And Darío with him.",
	["En el contestador, Don Ernesto: «Gracias por cerrar la cuenta. Dejen las llaves en el cajón.»"] = "On the answering machine, Don Ernesto: \"Thanks for closing the account. Leave the keys in the drawer.\"",
	["FINAL 3/3: MIRAR HASTA EL FINAL"] = "ENDING 3/3: WATCH TO THE END",
	["Mirás hasta el final. La tele se vuelve el local, y en el local estás vos, de espaldas, mirando la tele."] = "You watch to the end. The TV becomes the store, and in the store there you are, with your back turned, watching the TV.",
	["El turno noche sigue grabado."] = "The night shift is still recorded.",
	["Mañana empieza alguien nuevo."] = "Tomorrow someone new starts.",
	["Todavía no. Esta cinta no se deja grabar tan fácil."] = "Not yet. This tape isn't so easy to record over.",
	["Hace falta la cinta sin etiqueta en la mano."] = "You need to hold the unlabeled tape.",
	["Grabar encima"] = "Record over", ["Videocasetera"] = "VCR",
	-- Noches
	["Primer turno"] = "First shift", ["Anomalías"] = "Anomalies", ["Las reglas de Darío"] = "Darío's rules", ["Sin luz"] = "No power", ["En vivo"] = "Live",
	["Atender clientes"] = "Serve customers", ["Rebobinar casetes"] = "Rewind tapes", ["Reponer por género"] = "Restock by genre",
	["Separar cintas dañadas"] = "Sort damaged tapes", ["Tirar la basura (patio)"] = "Take out the trash (yard)",
	["Limpiar manchas"] = "Clean stains", ["Cuidar el local"] = "Look after the store",
	["Cuando llegue un cliente, atendelo en el mostrador (E)."] = "When a customer arrives, serve them at the counter (E).",
	["Los casetes devueltos se rebobinan en la videocasetera (mantené E) y se reponen en su góndola."] = "Returned tapes are rewound in the VCR (hold E) and restocked on their shelf.",
	["Una cinta arrugada no se rebobina: va a la caja de dañadas."] = "A crinkled tape isn't rewound: it goes in the damaged box.",
	["Algo fuera de lugar: apuntale y apretá Q. Tu ficha cuenta las que encontraste."] = "Something out of place: aim at it and press Q. Your card counts the ones you found.",
	["El local también necesita cuidados: regá la planta, ordená las fichas, contá la caja... (se marcan con un contorno)."] = "The store needs looking after too: water the plant, sort the cards, count the register... (they're outlined).",
	["TE GRABARON."] = "YOU GOT RECORDED.", ["El turno se repite desde las 22:00."] = "The shift starts over from 22:00.",
	["Hay una nota nueva pegada en el local."] = "There's a new note stuck up in the store.",
	["Una cinta quedó sin recoger en el mostrador y se retiró."] = "A tape was left on the counter and was taken away.",
	-- Tareas y avisos del servidor
	["Contaminación"] = "Contamination", ["No hay nada raro ahí."] = "There's nothing strange there.",
	["Ya llevás una bolsa."] = "You're already carrying a bag.", ["Tenés un casete en la mano. Dejalo primero."] = "You have a tape in your hand. Drop it first.",
	["Llevá la bolsa al contenedor del patio."] = "Take the bag to the dumpster in the yard.", ["Levantar bolsa"] = "Pick up bag",
	["Bolsa de basura"] = "Trash bag", ["No llevás ninguna bolsa."] = "You aren't carrying a bag.", ["Bolsa tirada."] = "Bag thrown away.",
	["Tenés las manos ocupadas con la bolsa."] = "Your hands are full with the bag.", ["Tirar bolsa"] = "Throw away bag",
	["Contenedor"] = "Dumpster", ["Limpiar"] = "Clean", ["Mancha"] = "Stain", ["Limpiado."] = "Cleaned.", ["Listo."] = "Done.",
	["Rechazar cliente"] = "Turn away customer", ["Atender"] = "Serve", ["Mostrador"] = "Counter",
	["Apagar tele"] = "Turn off TV", ["Cambiar canal"] = "Change channel", ["Tele del mostrador"] = "Counter TV",
	["Apagaste la tele."] = "You turned off the TV.", ["Prendiste la tele."] = "You turned on the TV.",
	["Apagar / prender"] = "Turn off / on", ["Radio"] = "Radio", ["Radio apagada."] = "Radio off.", ["Radio prendida."] = "Radio on.",
	["Asustar a todos"] = "Scare everyone", ["ASUSTAR A TODOS"] = "SCARE EVERYONE",
	["Solo se puede asustar durante el turno."] = "You can only scare during a shift.",
	["Los espectadores no pueden asustar."] = "Spectators can't scare.",
	["Solo podés revivir si quedaste fuera de la noche."] = "You can only revive if you're out of the night.",
	["Producto desconocido."] = "Unknown product.", ["Esta compra todavía no está disponible."] = "This purchase isn't available yet.",
	["No se pudo abrir la compra. Probá de nuevo."] = "The purchase couldn't be opened. Try again.",
	["Sin título"] = "Untitled", ["Casete sin etiqueta"] = "Unlabeled tape", ["Tomar"] = "Take",
	["Ya tenés un casete en la mano."] = "You already have a tape in your hand.",
	["Casete sin etiqueta: en la videocasetera se reproduce (mantené E) o se le graba encima (mantené R). Con G lo soltás."] = "Unlabeled tape: in the VCR you can play it (hold E) or record over it (hold R). Drop it with G.",
	["Le grabaste encima a la cinta sin etiqueta: ya no se puede mirar y el Socio se calma."] = "You recorded over the unlabeled tape: it can't be watched anymore and the Member calms down.",
	["Le grabaste encima a una cinta anómala: ya no puede volver a circular."] = "You recorded over an anomalous tape: it can't go back into circulation.",
	["Esa cinta no necesita que le graben encima."] = "That tape doesn't need to be recorded over.",
	["Hace falta una cinta en la mano para grabarle encima."] = "You need a tape in your hand to record over it.",
	["No tenés ningún casete en la mano."] = "You don't have a tape in your hand.", ["Soltaste el casete."] = "You dropped the tape.",
	["Cayó un casete en el buzón de devoluciones."] = "A tape dropped into the return slot.",
	["Algo cayó en el buzón. Es un casete sin caja ni etiqueta."] = "Something dropped into the slot. It's a tape with no case or label.",
	["Regar la planta"] = "Water the plant", ["Planta"] = "Plant", ["Ordenar las fichas"] = "Sort the cards", ["Fichas de socios"] = "Member cards",
	["Enderezar el cartel"] = "Straighten the sign", ["Cartel de oferta"] = "Sale sign", ["Limpiar el vidrio"] = "Clean the glass", ["Ventana"] = "Window",
	["Contar la caja"] = "Count the register", ["Caja registradora"] = "Cash register",
	["Ficha completa. Aguantá hasta las 04:00."] = "Card complete. Hold out until 04:00.",
	["Quedó un casete sin etiqueta en el local."] = "An unlabeled tape was left in the store.",
	["No sabés en qué góndola va esta cinta."] = "You don't know which shelf this tape goes on.",
	["Esa cinta está arrugada: va en la caja de dañadas."] = "That tape is crinkled: it goes in the damaged box.",
	["Primero hay que rebobinarla."] = "It has to be rewound first.",
	["Ya sacaste el casete que pidió el cliente."] = "You already took the tape the customer asked for.",
	["No tenés nada para reponer y nadie te pidió nada de este género."] = "You have nothing to restock and nobody asked for this genre.",
	["La cinta no responde."] = "The tape doesn't respond.",
	["La cinta está arrugada: no se puede rebobinar. A la caja de dañadas."] = "The tape is crinkled: it can't be rewound. Put it in the damaged box.",
	["Ya está rebobinado."] = "It's already rewound.", ["Esa cinta está bien: no va en la caja de dañadas."] = "That tape is fine: it doesn't go in the damaged box.",
	["Usar góndola"] = "Use shelf", ["Rebobinar"] = "Rewind", ["Videocasetera (rebobinar / reproducir)"] = "VCR (rewind / play)",
	["Separar cinta"] = "Sort tape", ["Caja de dañadas"] = "Damaged box",
	["Mirar"] = "Watch",
	["Quedaste atrapado en la cinta. Mirá a tus compañeros desde afuera: ellos ven tu estatua en el motel."] = "You're trapped in the tape. Watch your teammates from outside: they can see your statue at the motel.",
	-- Multijugador
	["Un jugador"] = "Single player",
	["No se pudo entrar al servidor de juego. Probá de nuevo."] = "Couldn't join the game server. Try again.",
	["La sala se cerró."] = "The room was closed.", ["Creando la sala..."] = "Creating the room...", ["No se pudo crear la sala."] = "Couldn't create the room.",
	["Buscando la sala..."] = "Looking for the room...", ["No se pudo entrar a la sala."] = "Couldn't join the room.", ["La sala está llena."] = "The room is full.",
	["No existe ninguna sala con ese código (o ya empezó)."] = "No room exists with that code (or it already started).",
	["Preparando el servidor de juego..."] = "Preparing the game server...", ["No se pudo iniciar la partida."] = "Couldn't start the game.",
	["Preparando tu partida..."] = "Preparing your game...", ["No se pudo preparar la partida."] = "Couldn't prepare the game.",
	["No se pudo conectar con los servidores. Probá de nuevo en un momento."] = "Couldn't connect to the servers. Try again in a moment.",
	["No se pudo crear la sala. Probá de nuevo."] = "Couldn't create the room. Try again.", ["La sala ya empezó."] = "The room already started.",
	["No se pudo preparar el servidor de juego. Probá de nuevo."] = "Couldn't prepare the game server. Try again.",
	["La sala ya no existe."] = "The room no longer exists.", ["Solo el anfitrión puede iniciar la partida."] = "Only the host can start the game.",
	["No se pudo preparar la partida. Probá de nuevo."] = "Couldn't prepare the game. Try again.",
	["Entrando a la sala..."] = "Joining the room...",
	-- Interfaz del menú
	["VIDEOCLUB ESTRELLA"] = "STAR VIDEO CLUB", ["TURNO NOCHE · NOVIEMBRE DE 1997"] = "NIGHT SHIFT · NOVEMBER 1997",
	["UN JUGADOR"] = "SINGLE PLAYER", ["MULTIJUGADOR"] = "MULTIPLAYER", ["AJUSTES"] = "SETTINGS", ["CÓMO JUGAR"] = "HOW TO PLAY",
	["VOLVER"] = "BACK", ["CARGANDO..."] = "LOADING...", ["REUNIENDO AL EQUIPO..."] = "GATHERING THE TEAM...",
	["SALA DE ESPERA"] = "WAITING ROOM", ["Sos el anfitrión. Cuando estén todos, empezá el turno."] = "You're the host. When everyone is here, start the shift.",
	["INICIAR"] = "START", ["Iniciando la partida... entrando al servidor de juego."] = "Starting the game... joining the game server.",
	["Salas públicas"] = "Public rooms", ["No hay salas públicas por ahora.\nCreá una o unite con un código."] = "There are no public rooms right now.\nCreate one or join with a code.",
	["CREAR"] = "CREATE", ["UNIRSE POR CÓDIGO"] = "JOIN BY CODE", ["CREAR SALA"] = "CREATE ROOM", ["Visibilidad de la sala"] = "Room visibility",
	["PÚBLICA"] = "PUBLIC", ["PRIVADA"] = "PRIVATE", ["CÓDIGO"] = "CODE", ["UNIRSE"] = "JOIN",
	["SALIR DE LA SALA"] = "LEAVE ROOM", ["SALIR AL MENÚ PRINCIPAL"] = "EXIT TO MAIN MENU",
	["Música"] = "Music", ["Sonido ambiente"] = "Ambient sound", ["Estática del filtro VHS"] = "VHS filter static",
	["Idioma: Español (más idiomas pronto)"] = "Language: English (follows your Roblox language)",
	["WASD  moverte"] = "WASD  move", ["E  interactuar  (mantené E donde lo pida)"] = "E  interact  (hold E where asked)",
	["R (mantener)  segunda acción: rechazar, grabar encima"] = "R (hold)  second action: turn away, record over",
	["Tab  mostrar u ocultar tu ficha de socio      G  soltar lo que llevás en la mano"] = "Tab  show or hide your member card      G  drop what you're holding",
	["Q  marcar algo fuera de lugar (apuntale)"] = "Q  mark something out of place (aim at it)",
	["F  linterna      M  ajustes"] = "F  flashlight      M  settings",
	["Ctrl  soltar o atrapar el mouse (para tocar botones, como comprar)"] = "Ctrl  free or lock the mouse (to click buttons, like buying)",
	["Aguantá el turno noche hasta las 04:00."] = "Survive the night shift until 04:00.",
	["Atendé clientes, rebobiná y reponé casetes, tirá la basura en el patio y limpiá las manchas."] = "Serve customers, rewind and restock tapes, take the trash out to the yard and clean the stains.",
	["El Socio N° 0000 se arrastra más lento cuando lo mirás."] = "Member No. 0000 crawls much slower when you look at him.",
	["el anfitrión"] = "the host",
	-- Espectador, ratón y tienda
	["No queda nadie en pie"] = "Nobody is left standing", ["ESTÁS FUERA DE LA NOCHE"] = "YOU'RE OUT OF THE NIGHT",
	["Tus compañeros siguen jugando. Ellos ven tu estatua en el motel."] = "Your teammates are still playing. They can see your statue at the motel.",
	["Desbloquear mouse: Ctrl"] = "Unlock mouse: Ctrl",
	["MOUSE LIBRE · Ctrl para volver a jugar"] = "MOUSE FREE · Ctrl to go back to playing",
	["Tomar escoba"] = "Take broom", ["Guardar escoba"] = "Put broom back",
	["La escoba ya la tiene alguien (o quedó tirada en el piso)."] = "Someone already has the broom (or it was left on the floor).",
	-- Interfaz en juego
	["EN MANO: nada"] = "IN HAND: nothing", ["EN MANO: casete sin etiqueta (G: soltar)"] = "IN HAND: unlabeled tape (G: drop)",
	["EL SOCIO ESPERA SU CINTA"] = "THE MEMBER IS WAITING FOR HIS TAPE",
	["CLIENTE DEVUELVE UN CASETE (atendelo en el mostrador)"] = "CUSTOMER IS RETURNING A TAPE (serve them at the counter)",
	["TURNO NOCHE - Tab: ocultar"] = "NIGHT SHIFT - Tab: hide",
	["Ese no va acá"] = "That doesn't go here", ["Rebobinado: ..."] = "Rewound: ...",
	["04:00 - FIN DEL TURNO"] = "04:00 - END OF SHIFT",
	["WASD moverte · E interactuar · Tab ficha"] = "WASD move · E interact · Tab card",
	["Atendé el teléfono del mostrador."] = "Answer the counter phone.",
	["REBOBINADA"] = "REWOUND", ["REBOBINAR"] = "REWIND", ["ARRUGADA"] = "CRINKLED",
	["Ese no es un recuerdo de la cinta: es el Socio. Con la Q no se lo marca: hay que mirarlo, porque cuando lo mirás se arrastra mucho más lento."] = "That's not a memory from the tape: it's the Member. You don't mark him with Q: you have to look at him, because when you look at him he crawls much slower.",
	-- Tele
	["SIN SEÑAL"] = "NO SIGNAL", ["CARTA DE AJUSTE"] = "TEST PATTERN",
	["VIDEOCLUB ESTRELLA\n2x1 LOS MARTES\nREBOBINE ANTES DE DEVOLVER"] = "STAR VIDEO CLUB\n2x1 ON TUESDAYS\nREWIND BEFORE RETURNING",
	["NOTICIERO 23 HS\nSIGUE SIN APARECER DARÍO F.,\nEMPLEADO DE UN VIDEOCLUB"] = "11 PM NEWS\nDARÍO F., VIDEO STORE EMPLOYEE,\nSTILL MISSING",
	["CANAL 9\n- - - - - - - -\nTRANSMISIÓN SUSPENDIDA"] = "CHANNEL 9\n- - - - - - - -\nBROADCAST SUSPENDED",
	["SOCIO N° 0000\nESPERA SU CINTA"] = "MEMBER NO. 0000\nWAITING FOR HIS TAPE", ["▶ REPRODUCIENDO"] = "▶ PLAYING",
	-- Mundo (carteles del local)
	["DAÑADAS"] = "DAMAGED", ["HAGASE SOCIO"] = "BECOME A MEMBER", ["HAGASE  SOCIO"] = "BECOME A MEMBER", ["2x1 LOS MARTES"] = "2x1 ON TUESDAYS",
	["REBOBINE ANTES DE DEVOLVER"] = "REWIND BEFORE RETURNING", ["ESTRENOS"] = "NEW RELEASES", ["DEVOLUCIONES"] = "RETURNS",
	["CÓMO SE TRABAJA"] = "HOW WE WORK", ["Turno noche · Videoclub Estrella"] = "Night shift · Star Video Club",
	["CONTROLES"] = "CONTROLS", ["EL TURNO"] = "THE SHIFT",
	["Interactuar (atender, tomar, usar)"] = "Interact (serve, take, use)", ["Mantener: rechazar o grabar"] = "Hold: turn away or record",
	["Soltar el casete"] = "Drop the tape", ["Marcar una anomalía"] = "Mark an anomaly", ["Linterna (si se corta la luz)"] = "Flashlight (if the power goes out)",
	["Ocultar la ficha"] = "Hide the card", ["Soltar el mouse (botones)"] = "Free the mouse (buttons)", ["Correr (se cansa)"] = "Sprint (you get tired)",
	["1. Atendé al cliente en el mostrador"] = "1. Serve the customer at the counter", ["2. Rebobiná las cintas devueltas"] = "2. Rewind returned tapes",
	["3. Las dañadas, a la caja roja"] = "3. Damaged ones go in the red box", ["4. Cada cinta a la góndola de su género"] = "4. Each tape on its genre's shelf",
	["5. Basura al patio, manchas a limpiar"] = "5. Trash to the yard, clean the stains",
	["5. Basura al patio; manchas con escoba"] = "5. Trash to the yard; stains need the broom",
	["FRÁGIL"] = "FRAGILE", ["NO TIRAR PAPEL AL INODORO"] = "DO NOT FLUSH PAPER", ["¡OFERTA!"] = "SALE!", ["LOS MARTES"] = "ON TUESDAYS",
	["en alquileres"] = "on rentals", ["NO COMER LO DE OTROS"] = "DON'T EAT OTHERS' FOOD", ["DARÍO"] = "DARÍO",
	["TURNOS\nLUN  DARÍO\nMAR  DARÍO\nMIE  DARÍO\nJUE  ---"] = "SHIFTS\nMON  DARÍO\nTUE  DARÍO\nWED  DARÍO\nTHU  ---",
	["SOLO BOLSAS CERRADAS"] = "CLOSED BAGS ONLY", ["RUTA 8\nSALDÁS 12 KM"] = "ROUTE 8\nEXIT IN 12 KM", ["MOTEL LUNA"] = "MOTEL LUNA",
	["HABITACIONES · TV COLOR"] = "ROOMS · COLOR TV", ["24 HS"] = "24 HRS", ["TV COLOR"] = "COLOR TV",
	["junto a la pared izquierda"] = "by the left wall", ["entre ACCIÓN y TERROR"] = "between ACTION and HORROR",
	["entre TERROR y COMEDIA"] = "between HORROR and COMEDY", ["entre COMEDIA y DRAMA"] = "between COMEDY and DRAMA",
	["entre DRAMA e INFANTIL"] = "between DRAMA and KIDS", ["junto a la pared derecha"] = "by the right wall",
	["en la puerta del depósito"] = "at the storeroom door", ["en la puerta del baño"] = "at the bathroom door", ["cerca de la entrada"] = "near the entrance",
	["Canal "] = "Channel ",
	["[E] sacar la cinta"] = "[E] eject the tape",

	-- Cepillo de mano y manchas
	["Limpiar manchas (escoba del baño)"] = "Clean stains (bathroom broom)",
	["Mancha (con escoba)"] = "Stain (needs the broom)",
	["Tomar o guardar"] = "Take or put back", ["Escoba"] = "Broom",
	["Tenés la escoba. Mantené E sobre una mancha para limpiarla."] = "You have the broom. Hold E on a stain to clean it.",
	["Guardaste la escoba."] = "You put the broom back.",
	["Para limpiar hace falta la escoba: está apoyada en el baño."] = "You need the broom to clean: it leans in the bathroom.",
	-- Insignias
	["Grabar encima"] = "Record Over", ["Cuenta cerrada"] = "Account Closed",
	["Hasta el final"] = "To the End", ["Cinta completa"] = "Complete Tape", ["Insomnio"] = "Insomnia", ["Turno eterno"] = "Eternal Shift",
	["Mitad de camino"] = "Halfway There", ["Te vi venir"] = "Saw You Coming", ["Turno compartido"] = "Shared Shift", ["Sin descanso"] = "No Rest",
	["Sobreviví la tercera noche en el modo Historia."] = "Survive the third night in Story mode.",
	["Rechazá al Socio cuando se presenta como cliente."] = "Turn the Member away when he shows up as a customer.",
	["Sobreviví una noche con otro jugador en el local."] = "Survive a night with another player in the store.",
	["Sobreviví 20 noches seguidas en el modo Sin fin."] = "Survive 20 nights in a row in Endless mode.",
	["WASD  moverte      Shift (mantener)  correr, pero se cansa"] = "WASD  move      Shift (hold)  sprint, but you get tired",
	["Soltaste la bolsa: volvió a su lugar."] = "You dropped the bag: it went back to its spot.",
	["Soltaste la escoba."] = "You dropped the broom.",
	["Levantar escoba"] = "Pick up broom",
	["Tenés un casete en la mano. Soltalo primero (G)."] = "You have a tape in your hand. Drop it first (G).",
	["Tenés una bolsa en las manos. Soltala primero (G)."] = "You have a bag in your hands. Drop it first (G).",
	["Tenés las manos ocupadas con la bolsa. Soltala con G."] = "Your hands are full with the bag. Drop it with G.",
	["Tenés las manos ocupadas con la escoba. Soltala con G."] = "Your hands are full with the broom. Drop it with G.",
	["Tenés la escoba. Mantené E sobre una mancha para limpiarla. Con G la soltás."] = "You have the broom. Hold E on a stain to clean it. Drop it with G.",
	-- Pase de colores de linterna
	["Cálida"] = "Warm", ["Fría"] = "Cold", ["Verde"] = "Green", ["Roja"] = "Red", ["Violeta"] = "Violet",
	["¡Gracias! Ya podés elegir el color de la linterna en Ajustes."] = "Thank you! You can now pick the flashlight color in Settings.",
	-- Ranking y modificador diario
	["RANKING"] = "LEADERBOARD",
	["SIN FIN · MEJORES RACHAS"] = "ENDLESS · BEST STREAKS",
	["Todavía no hay récords. Sé el primero."] = "No records yet. Be the first.",
	["NOCHES"] = "NIGHTS",
	["Hoy en Sin fin:"] = "Today in Endless:",
	["Sin linterna"] = "No flashlight",
	["Socio veloz"] = "Fast Member",
	["Apagón"] = "Blackout",
	["Turno sin pausa"] = "Non-stop shift",
	["Hoy no hay linterna: al Socio se lo frena solo con mirarlo."] = "No flashlight today: you slow the Member just by looking at him.",
	["Hoy el Socio es mucho más rápido."] = "Today the Member is much faster.",
	["Hoy la luz se corta desde el principio de cada noche."] = "Today the power goes out at the start of every night.",
	["Hoy el Socio anda suelto desde el primer minuto."] = "Today the Member is loose from the very first minute.",
	-- Pistas contextuales (Server/Pistas)
	["Llevás un casete. Entregáselo al cliente en el mostrador (E) o dejalo con G."] = "You are carrying a tape. Hand it to the customer at the counter (E) or drop it with G.",
	["Una bolsa de basura: llevala al contenedor del patio (puerta del fondo, a la derecha). Con la bolsa en las manos no podés tomar casetes."] = "A trash bag: take it to the dumpster in the yard (back door, on the right). You can't pick up tapes while carrying it.",
	["Una mancha en el piso: tomá la escoba apoyada en la pared del baño (E) y mantené E sobre la mancha. Con G soltás la escoba."] = "A stain on the floor: grab the broom leaning on the bathroom wall (E) and hold E on the stain. Drop the broom with G.",
	["Cuidar el local: lo que tiene contorno se hace manteniendo E."] = "Looking after the store: anything with an outline is done by holding E.",
	["El Socio solo se frena si lo mirás con la linterna prendida (F). Mirarlo sin luz no sirve, y la batería se gasta."] = "The Member only slows down if you look at him with the flashlight on (F). Looking without light does nothing, and the battery drains.",
	["Mantené Shift para correr. Te cansás: la barrita de abajo muestra tu energía."] = "Hold Shift to run. You get tired: the little bar below shows your energy.",
	["Una anomalía: apuntale y apretá Q antes de que se te tire encima."] = "An anomaly: aim at it and press Q before it jumps on you.",
	["Se cortó la luz. Usá la linterna (F) y no la gastes: tiene batería."] = "The power is out. Use the flashlight (F) and don't waste it: it has a battery.",
	-- Advertencia de terror
	["ADVERTENCIA"] = "WARNING",
	["Este es un juego de terror."] = "This is a horror game.",
	["Contiene sustos fuertes, luces intermitentes, destellos y estática, sonidos muy intensos y escenas perturbadoras."] = "It contains loud jump scares, flashing lights, flashes and static, very intense sounds and disturbing scenes.",
	["NO se recomienda para personas con epilepsia o sensibilidad a las luces intermitentes, con afecciones cardíacas, ansiedad o trastornos de pánico, ni para menores sensibles al terror."] = "NOT recommended for people with epilepsy or sensitivity to flashing lights, heart conditions, anxiety or panic disorders, or for minors who are sensitive to horror.",
	["Si te sentís mal en cualquier momento, dejá de jugar."] = "If you feel unwell at any moment, stop playing.",
	["ENTENDIDO, CONTINUAR"] = "I UNDERSTAND, CONTINUE",
	-- Tienda
	["TIENDA"] = "SHOP", ["TIENDA (B)"] = "SHOP (B)", ["B · TIENDA"] = "B · SHOP", ["AYUDA"] = "HELP", ["ASPECTO"] = "LOOK", ["RADIO"] = "RADIO", ["PROPINA"] = "TIP",
	["CERRAR (B)"] = "CLOSE (B)", ["ROPA"] = "CLOTHES", ["FILTROS DE CINTA"] = "TAPE FILTERS", ["ESTACIONES"] = "STATIONS",
	["COMPRADO"] = "OWNED", ["QUITAR"] = "REMOVE", ["EQUIPAR"] = "EQUIP", ["LIBRE"] = "FREE", ["INCLUIDA"] = "INCLUDED", ["PREMIUM"] = "PREMIUM",
	["Incluida."] = "Included.", ["Con el Pase de Radio."] = "With the Radio Pass.",
	["Cómo cambiar de estación"] = "How to change station", ["Mirá la radio del mostrador y apretá R."] = "Look at the counter radio and press R.",
	["Las compras se pagan con Robux y las ayudas valen solo durante el turno."] = "Purchases are paid with Robux and the help items only work during the shift.",
	["Ningún compañero está fuera de la noche."] = "No teammate is out of the night.", ["Solo si quedaste fuera de la noche."] = "Only if you're out of the night.",
	["AMULETO ✦"] = "AMULET ✦", ["LINTERNA: SIN BATERÍA"] = "FLASHLIGHT: NO BATTERY",
	["Amuleto"] = "Amulet", ["Absorbe una captura del Socio esta noche."] = "Absorbs one Member capture tonight.",
	["Pausa de cinta"] = "Tape pause", ["Congela al Socio unos segundos."] = "Freezes the Member for a few seconds.",
	["Revivir a un compañero"] = "Revive a teammate", ["Un compañero que quedó fuera vuelve a la noche."] = "A teammate who is out comes back to the night.",
	["Revivir"] = "Revive", ["Si quedaste fuera, volvés a jugar al instante."] = "If you're out, you play again instantly.",
	["Asustar a todos"] = "Scare everyone", ["Un screamer para los demás jugadores."] = "A jumpscare for the other players.",
	["Gorra de Don Ernesto"] = "Don Ernesto's cap", ["La gorra roja del dueño del Videoclub."] = "The Video Club owner's red cap.",
	["Chaleco del Videoclub"] = "Video Club vest", ["El uniforme oficial, con la estrella en el pecho."] = "The official uniform, with the star on the chest.",
	["Camiseta del Socio"] = "Member's shirt", ["Negra, con el número 0000. No mires atrás."] = "Black, with the number 0000. Don't look back.",
	["Filtro blanco y negro"] = "Black and white filter", ["La cinta en blanco y negro, como una cámara de seguridad."] = "The tape in black and white, like a security camera.",
	["Filtro 8 mm"] = "8 mm filter", ["Colores gastados y cálidos de película vieja."] = "Worn, warm colors of old film.",
	["Filtro sepia"] = "Sepia filter", ["Todo en tonos de fotografía antigua."] = "Everything in old photograph tones.",
	["Pase de Radio"] = "Radio Pass", ["Desbloquea las estaciones extra de la radio del local."] = "Unlocks the extra stations of the store radio.",
	["Radio AM"] = "AM Radio", ["Cinta gastada"] = "Worn tape",
	["Propina chica"] = "Small tip", ["Un cafecito para Don Ernesto."] = "A little coffee for Don Ernesto.",
	["Propina"] = "Tip", ["Para las cintas nuevas."] = "For the new tapes.",
	["Propina grande"] = "Big tip", ["Don Ernesto no lo va a olvidar."] = "Don Ernesto won't forget it.",
	["Ya lo tenés: equipalo desde la tienda."] = "You already have it: equip it from the shop.",
	["No hay ningún compañero fuera de la noche."] = "No teammate is out of the night.",
	["Ese jugador ya no está fuera de la noche."] = "That player is no longer out of the night.",
	["El amuleto se compra durante el turno, estando en pie."] = "The amulet is bought during the shift, while standing.",
	["Ya tenés un amuleto."] = "You already have an amulet.",
	["La pausa de cinta se usa durante el turno, estando en pie."] = "The tape pause is used during the shift, while standing.",
	["El Socio no está en el local."] = "The Member is not in the store.",
	["Tenés un amuleto: absorbe la próxima captura."] = "You have an amulet: it absorbs the next capture.",
	["Ya no había nadie fuera: recibiste un amuleto."] = "Nobody was out anymore: you got an amulet.",
	["Todavía no compraste eso."] = "You haven't bought that yet.",
	["Las estaciones extra son del Pase de Radio (tienda: tecla B)."] = "The extra stations need the Radio Pass (shop: B key).",
	["Producto desconocido."] = "Unknown product.",
	-- Logros (menú)
	["LOGROS"] = "ACHIEVEMENTS", ["DESBLOQUEADO"] = "UNLOCKED", ["BLOQUEADO"] = "LOCKED",
	["Sobreviví tu primera noche en el Videoclub Estrella."] = "Survive your first night at Star Video Club.",
	["Llegá a la quinta noche, cuando el Socio ya está adentro."] = "Reach the fifth night, when the Member is already inside.",
	["Alcanzá el final REBOBINAR."] = "Reach the REWIND ending.",
	["Alcanzá el final verdadero: DEVOLVER."] = "Reach the true ending: RETURN.",
	["Alcanzá el final MIRAR HASTA EL FINAL."] = "Reach the WATCH TO THE END ending.",
	["Alcanzá los tres finales del Videoclub Estrella."] = "Reach all three endings of Star Video Club.",
	["Sobreviví 5 noches seguidas en el modo Sin fin."] = "Survive 5 nights in a row in Endless mode.",
	["Sobreviví 10 noches seguidas en el modo Sin fin."] = "Survive 10 nights in a row in Endless mode.",
	-- Modo Sin fin
	["HISTORIA"] = "STORY", ["SIN FIN"] = "ENDLESS", ["SIN FIN (BLOQUEADO)"] = "ENDLESS (LOCKED)",
	["MODO: HISTORIA"] = "MODE: STORY", ["MODO: SIN FIN"] = "MODE: ENDLESS",
	["El modo Sin fin se desbloquea al alcanzar un final de la historia."] = "Endless mode unlocks once you reach an ending in the story.",
	["Turno sin fin"] = "Endless shift",
	["Sin fin: cada noche es peor y no hay final. Aguantá todo lo que puedas."] = "Endless: every night is worse and there is no ending. Hold out as long as you can.",
	["El turno sin fin vuelve a empezar desde la noche 1."] = "The endless shift starts over from night 1.",
}

-- ===== Patrones (textos con datos adentro) =====
-- Cada uno: { patrón de Lua, función que arma el texto en inglés con las capturas }.
local function t(texto) -- referencia adelantada
	return Idioma.t(texto)
end

local PATRONES = {
	{ "^NOCHE (%d+)$", function(n) return "NIGHT " .. n end },
	{ "^Buenas noches%. ¿Tenés algo de (.+)%?$", function(g) return "Good evening. Do you have anything in " .. t(g) .. "?" end },
	{ "^Hola, busco una de (.+) para esta noche%.$", function(g) return "Hi, I'm looking for a " .. t(g) .. " one for tonight." end },
	{ "^¿Me recomendás una de (.+)%?$", function(g) return "Can you recommend a " .. t(g) .. " one?" end },
	{ "^Notas de Darío mal interpretadas: (%d+)$", function(n) return "Darío's notes misread: " .. n end },
	{ "^Máscara · R%$ (%d+)$", function(n) return "Mask · R$ " .. n end },
	{ "^(%d+) / (%d+) desbloqueados$", function(a, b) return a .. " / " .. b .. " unlocked" end },
	{ "^Récord en Sin fin: (%d+) noches$", function(n) return "Endless record: " .. n .. " nights" end },
	{ "^Noches superadas: (%d+)$", function(n) return "Nights survived: " .. n end },
	{ "^Linterna: (.+)$", function(x) return "Flashlight: " .. t(x) end },
	{ "^Colores de linterna · pase R%$ (%d+)$", function(n) return "Flashlight colors · pass R$ " .. n end },
	{ "^(.+) marcó a la criatura%.$", function(x) return x .. " marked the creature." end },
	{ "^Tu récord: (%d+) noches$", function(n) return "Your record: " .. n .. " nights" end },
	{ "^Récord: (%d+)$", function(n) return "Record: " .. n end },
	{ "^Canal (%d+)$", function(n) return "Channel " .. n end },
	{ "^CANAL (%d+)$", function(n) return "CHANNEL " .. n end },
	{ "^Anomalía registrada %((%d+)/(%d+)%)%.$", function(a, b) return "Anomaly logged (" .. a .. "/" .. b .. ")." end },
	{ "^Anomalías detectadas: (%d+)/(%d+)$", function(a, b) return "Anomalies detected: " .. a .. "/" .. b end },
	{ "^ANOMALÍAS %(Q%): (%d+)/(%d+)$", function(a, b) return "ANOMALIES (Q): " .. a .. "/" .. b end },
	{ "^Clientes que se fueron sin atender: (%d+)$", function(n) return "Customers who left without being served: " .. n end },
	{ "^Cintas anómalas repuestas por error: (.+)$", function(x) return "Anomalous tapes restocked by mistake: " .. x end },
	{ "^%[(.)%] (.+) (%d+)/(%d+)$", function(m, nombre, a, b) return "[" .. m .. "] " .. t(nombre) .. " " .. a .. "/" .. b end },
	{ "^(.+): (%d+)/(%d+)$", function(nombre, a, b) return t(nombre) .. ": " .. a .. "/" .. b end },
	{ "^CLIENTE PIDE: (.+)$", function(g) return "CUSTOMER WANTS: " .. t(g) end },
	{ "^SOCIO N° (%d+)$", function(n) return "MEMBER NO. " .. n end },
	{ "^Socio N° (%d+)%. (.+)$", function(n, x) return "Member No. " .. n .. ". " .. t(x) end },
	{ "^EN MANO: (.+) %((.+), (.+)%) %(G: soltar%)$", function(titulo, genero, estado)
		local estados = { ["sin rebobinar"] = "not rewound", rebobinada = "rewound", arrugada = "crinkled" }
		return "IN HAND: " .. t(titulo) .. " (" .. t(genero) .. ", " .. (estados[estado] or estado) .. ") (G: drop)"
	end },
	{ "^Pidió algo de (.+)%. Sacale un casete de esa góndola%.$", function(g) return "They asked for something from " .. t(g) .. ". Take a tape from that shelf." end },
	{ "^Ese no es el que pidió: quiere algo de (.+)%.$", function(g) return "That's not what they asked for: they want something from " .. t(g) .. "." end },
	{ "^Eso no es (.+)%. Fijate el género de la carátula%.$", function(g) return "That isn't " .. t(g) .. ". Check the genre on the cover." end },
	{ "^El cliente pidió (.+), no (.+)%.$", function(a, b) return "The customer asked for " .. t(a) .. ", not " .. t(b) .. "." end },
	{ "^Sacaste: (.+)%. Llevaselo al cliente%.$", function(x) return "You took: " .. t(x) .. ". Bring it to the customer." end },
	{ "^Repuesto: (.+)$", function(x) return "Restocked: " .. t(x) end },
	{ "^Rebobinado: (.+)$", function(x) return "Rewound: " .. t(x) end },
	{ "^Separada: (.+)$", function(x) return "Sorted: " .. t(x) end },
	{ "^Sacaste: (.+)$", function(x) return "You took: " .. t(x) end },
	{ "^Algo se movió (.+)%.$", function(z) return "Something moved " .. t(z) .. "." end },
	{ "^Suena el (.+)%. Acercate y apretá E para atender%.$", function(l) return "The " .. t(l) .. " is ringing. Get close and press E to answer." end },
	{ "^(.+) fue grabado %((%d+)/(%d+)%) y quedó atrapado en la cinta%.$", function(n, a, b) return n .. " was recorded (" .. a .. "/" .. b .. ") and got trapped in the tape." end },
	{ "^(.+) fue grabado %((%d+)/(%d+)%)%.$", function(n, a, b) return n .. " was recorded (" .. a .. "/" .. b .. ")." end },
	{ "^(.+) asustó a todos%.$", function(n) return n .. " scared everyone." end },
	{ "^(.+) volvió a la noche%.$", function(n) return n .. " is back in the night." end },
	{ "^Revivir a un compañero: (.+)$", function(n) return "Revive a teammate: " .. n end },
	{ "^LINTERNA: (%d+) s$", function(n) return "FLASHLIGHT: " .. n .. " s" end },
	{ "^El amuleto de (.+) se rompió%.$", function(n) return n .. "'s amulet broke." end },
	{ "^(.+) frenó la cinta: el Socio quedó congelado%.$", function(n) return n .. " stopped the tape: the Member froze." end },
	{ "^(.+) revivió a (.+)%.$", function(a, b) return a .. " revived " .. b .. "." end },
	{ "^(.+) dejó una propina para Don Ernesto%. ¡Gracias!$", function(n) return n .. " left a tip for Don Ernesto. Thank you!" end },
	{ "^Compraste: (.+)%.$", function(n) return "You bought: " .. t(n) .. "." end },
	{ "^Radio: (.+)%.$", function(n) return "Radio: " .. t(n) .. "." end },
	{ "^La cinta ya se frenó hace poco%. Probá en (%d+) s%.$", function(n) return "The tape was stopped recently. Try in " .. n .. " s." end },
	{ "^(.+) — Radio apagada%.$", function(n) return n .. " — Radio off." end },
	{ "^(.+) — Radio prendida%.$", function(n) return n .. " — Radio on." end },
	{ "^Alguien acaba de asustar a todos%. Probá en (%d+) s%.$", function(n) return "Someone just scared everyone. Try again in " .. n .. " s." end },
	{ "^Te sumaste a la noche (%d+)%. Tu ficha %(Tab%) dice qué falta; el equipo ya está en el local%.$", function(n) return "You joined night " .. n .. ". Your card (Tab) shows what's left; the team is already in the store." end },
	{ "^El código tiene (%d+) caracteres%.$", function(n) return "The code has " .. n .. " characters." end },
	{ "^Escribí el código de la sala %((%d+) caracteres%)$", function(n) return "Enter the room code (" .. n .. " characters)" end },
	{ "^CÓDIGO: (.+)$", function(c) return "CODE: " .. c end },
	{ "^Sala pública · (%d+)/(%d+) jugadores$", function(a, b) return "Public room · " .. a .. "/" .. b .. " players" end },
	{ "^Sala privada · (%d+)/(%d+) jugadores$", function(a, b) return "Private room · " .. a .. "/" .. b .. " players" end },
	{ "^(%d+) / (%d+) jugadores$", function(a, b) return a .. " / " .. b .. " players" end },
	{ "^Cantidad de jugadores %(máx%. (%d+)%)$", function(n) return "Number of players (max. " .. n .. ")" end },
	{ "^Esperando que (.+) empiece el turno%.%.%.$", function(n) return "Waiting for " .. t(n) .. " to start the shift..." end },
	{ "^Mirando a (.+)$", function(n) return "Watching " .. n end },
	{ "^REVIVIR · R%$ (%d+)$", function(n) return "REVIVE · R$ " .. n end },
	{ "^ASUSTAR A TODOS · R%$ (%d+)$", function(n) return "SCARE EVERYONE · R$ " .. n end },
	{ "^Calidad gráfica: (.+)$", function(x) return "Graphics quality: " .. x end },
	{ "^Hay (.+) en el local%.$", function(x) return "There is " .. t(x) .. " in the store." end },
	{ "^NOV (%d+) (%d+)  (%d+:%d+)$", function(a, b, c) return "NOV " .. a .. " " .. b .. "  " .. c end },
	{ "^Eso no es (.+)%.$", function(x) return "That isn't " .. t(x) .. "." end },
}

-- Texto con etiquetas de texto enriquecido (<font>, <b>...): se traduce solo lo que está entre etiquetas.
local function traducirEnriquecido(texto: string, idioma: string): string
	local salida = {}
	local pos = 1
	while pos <= #texto do
		local a, b = string.find(texto, "<[^>]+>", pos)
		local trozo = a and string.sub(texto, pos, a - 1) or string.sub(texto, pos)
		if trozo ~= "" then
			local espacioIni = string.match(trozo, "^%s*")
			local espacioFin = string.match(trozo, "%s*$")
			local nucleo = string.sub(trozo, #espacioIni + 1, #trozo - #espacioFin)
			table.insert(salida, espacioIni .. (nucleo ~= "" and Idioma.t(nucleo) or "") .. espacioFin)
		end
		if a then
			table.insert(salida, string.sub(texto, a, b))
			pos = b + 1
		else
			break
		end
	end
	return table.concat(salida)
end

local cache = {}

local function traducirInterno(texto: string): string?
	local exacto = EN[texto]
	if exacto then
		return exacto
	end
	for _, p in PATRONES do
		local capturas = { string.match(texto, p[1]) }
		if #capturas > 0 then
			return p[2](table.unpack(capturas))
		end
	end
	return nil
end

--- Traduce un texto del juego al idioma del jugador (si es español o no se conoce, lo devuelve igual).
function Idioma.t(texto: string): string
	if typeof(texto) ~= "string" or texto == "" or Idioma.actual() ~= "en" then
		return texto
	end
	local guardado = cache[texto]
	if guardado then
		return guardado
	end
	local resultado = traducirInterno(texto)
	if not resultado then
		if string.find(texto, "<", 1, true) and string.find(texto, ">", 1, true) then
			resultado = traducirEnriquecido(texto, "en")
		elseif string.find(texto, "\n", 1, true) then
			local lineas = {}
			for linea in string.gmatch(texto .. "\n", "(.-)\n") do
				table.insert(lineas, linea == "" and "" or Idioma.t(linea))
			end
			resultado = table.concat(lineas, "\n")
		elseif string.sub(texto, 1, 4) == "▶ " or string.sub(texto, 1, 4) == "● " then
			resultado = string.sub(texto, 1, 4) .. Idioma.t(string.sub(texto, 5))
		elseif string.find(texto, "\xC2\xB7", 1, true) and not traducirInterno(texto) then
			-- "algo · algo": cada parte por separado
			local partes = {}
			for parte in string.gmatch(texto .. " · ", "(.-) · ") do
				table.insert(partes, parte == "" and "" or Idioma.t(parte))
			end
			resultado = table.concat(partes, " · ")
		end
	end
	resultado = resultado or texto
	if resultado == texto and string.find(texto, "%a") then
		sinTraducir[texto] = (sinTraducir[texto] or 0) + 1 -- (sirve para ver qué falta traducir)
	end
	cache[texto] = resultado
	return resultado
end

function Idioma.sinTraducir()
	return sinTraducir
end

return Idioma
