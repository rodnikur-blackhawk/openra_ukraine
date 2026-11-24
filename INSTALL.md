# Red Alert: Україна — мод для OpenRA

Мод перетворює фракцію «Україна» в Red Alert на союзну сторону, озброєну технікою ЗСУ: Bayraktar TB2, дрон-камікадзе «Лютий», F-16, «Булат», «Оплот», БТР-4, Gepard, «Вільха», «Богдана», «Ратель С», Sea Baby, корвет «Гетьман Іван Мазепа», оператори БПЛА та агенти ГУР. Оборону складають бункер дронів і позиція «Стугна-П». Суперзброя: пуск «Фламінго», станція РЕБ «Покрова» та удар Storm Shadow; аеродром викликає аеромобільний десант на Мі-8.

Мод встановлюється окремо й **не змінює** звичайний Red Alert: обидві гри працюють паралельно.

## Що нового у версії 1.4.1

- **Боти воюють тактично.** Новий скрипт `scripts/ukraine-ai.lua` працює на всіх мапах для сутичок і керує тими юнітами ботів, з якими стандартний ШІ OpenRA не вміє поводитися. Ці юніти бот більше не кидає в загальні атакувальні загони.
- **Усі фракції (боти):**
  - **БТР у бою.** БТР (у України — БТР-4) чекає біля казарми з піхотою (до 5 бійців) і рушає, коли є бій: ворог біля бази або армія в полі. Щойно поруч ворожі війська (7 клітинок) чи будь-які ворожі будівлі (9 клітинок), піхота висаджується на місці бою, а БТР тримається позаду неї. Після бою, якщо наступна ціль близько, піхота йде пішки, а якщо далеко, БТР сам під'їжджає до свого загону, забирає його й везе далі (або назад на базу).
  - **Десант через воду.** Якщо до ворога не можна дійти суходолом, бот будує на верфі до двох десантних кораблів (LST), садить на них війська біля своєї бази й висаджує на березі біля ворожої бази — там, куди не дістає ворожа оборона. Завантажені БТР заїжджають у корабель разом із піхотою й після висадки воюють на ворожому березі. Швидкий бот («rush») тепер теж будує верф, якщо база біля води.
- **ППО перемикається на авіацію.** Gepard, зенітна вантажівка (Flak Truck), ракетник, есмінець, ракетний підводний човен і корвет «Мазепа» більше не продовжують стріляти по наземній цілі, коли поруч ворожий літак: на цей час їхня наземна зброя вимикається, і вони збивають авіацію; коли вона відлітає, повертаються до наземних цілей. Діє для всіх гравців і ботів.
- **Союзники мають БТР.** Англія, Франція й Німеччина будують БТР (APC), як в оригінальному Red Alert. Десантний корабель (LST) є в усіх фракцій, зокрема в України (будується на її військово-морській базі).
- **Бот за Україну:**
  - **Bayraktar TB2 більше не відхиляє ракети** (лише глушить радари, як і раніше).
  - **«Ратель С» проти будівель:** тепер справді атакує будівлі — раніше він не міг дотягнутися до центру великої будівлі й не спрацьовував (як у демо-вантажівки, підрив по будівлі тепер на відстані до 2 клітинок). Кожен «Ратель» знімає половину повного здоров'я будь-якої будівлі, тож два зносять будівельний центр чи будь-яку іншу будівлю. Техніку й піхоту, як і раніше, знищує з першого удару.
  - **Дрони в повітрі завжди є.** Рушій дозволяє ботові будувати літак лише тоді, коли для нього є вільний аеродром, тож перший TB2 чи F-16 займав єдиний аеродром, і нові дрони вже не з'являлися. Тепер боти за Україну будують більше аеродромів, а скрипт сам дозамовляє дрони: щонайменше 3 TB2 і 2 «Лютих» (бот «rush» — 2 TB2 і без «Лютих»); використані «Люті» поповнюються.
  - **Bayraktar TB2:** частина дронів кружляє над ключовими точками між базами й стежить за переміщенням ворога, решта б'є по техніці, кораблях і обороні там, де немає ворожої ППО, і на шляху до цілі її теж немає. Дрони виходять із зони ППО, щойно туди потрапили. Якщо біля своїх або союзних військ є невидимі юніти, міни чи підводні човни, один дрон летить над ними й підсвічує їх, щоб їх могли знищити. Бот «rush» має лише два TB2.
  - **«Лютий»** (крім бота «rush») летить залпами щонайменше по два на ворожі будівлі, які вже розвідано: передусім цінні (будівельний центр, заводи, електростанції, суперзброя) і найменш прикриті ППО. На будівельний центр іде два дрони.
  - **«Ратель С»** перехоплює ворожу техніку біля бази та біля своїх військ, а парами обходить оборонні споруди обхідним маршрутом і підриває будівлі. Один «Ратель» лишається вдома.
  - **Sea Baby** атакують групами від трьох (або одразу, якщо ворожі кораблі поруч із верф'ю) ворожі кораблі й верфі. Тепер вони вражають і верфі та інші споруди на воді. Виправлено ваду: раніше Sea Baby не могли підірвати корабель, що стоїть на місці (дальність спрацювання була меншою за відстань до сусідньої клітинки); тепер дрон вибухає з сусідньої клітинки, зокрема по діагоналі.
  - **Оператори БПЛА** будуються трохи частіше за стрільців.
  - **Агенти ГУР** обхідним маршрутом в обхід оборони йдуть до нафтопереробного заводу чи сховища найбагатшого ворога, по дорозі знищують піхоту, крадуть там гроші, а цінну техніку, що трапиться дорогою (комбайни, танки), викрадають.
  - **Аеромобільний десант на Мі-8** висаджується не посеред ворожої бази, а поруч із нею, подалі від ППО та оборонних споруд, з боку власної бази.
  - **«Богдана» й «Вільха»** тримаються за 7–8 клітинок позаду передової машини армії, не заходять у зону дії оборонних споруд і відходять, якщо ворог підійшов надто близько.
  - **F-16** злітають на перехоплення ворожої авіації біля бази та біля своїх військ (не глибоко в зоні ворожої ППО), по двоє на ціль.
  - **БТР-4** використовуються для швидкого перевезення піхоти (до 3–4 на бота).
- **Оборона й суперзброя у стилі стокових споруд Red Alert** (компактні, з поверхнями кольору гравця, без обводок; іконки оновлено, крім «Фламінго»):
  - **«Стугна-П»:** восьмикутний бетонний постамент зі сталевою палубою і пускова на триноги (світло-сірий блок наведення, два темно-оливкові тубуси); колір гравця — там же, де в радянського ЗРК: смуга вздовж низу постаменту та шеврон на палубі перед пусковою.
  - **Бункер дронів:** низький восьмикутний бункер з дахом кольору гравця, тарілкою й антеною; при кожному пуску люк у даху відчиняється, з нього злітає FPV-дрон, і люк зачиняється.
  - **«Покрова»** тепер має вигляд РЛС з фазованими ґратками: світла зрізана тригранна піраміда зі скошеними кутами й гофрованою обшивкою, з великою круглою антенною ґраткою на кожній грані, стоїть на залі з вивітреного бетону з широким поясом кольору гравця — у кольорах і фактурах стокового радара. При активації з вершини на кілька секунд б'є вгору блакитний промінь. Іконку зроблено з фото такого радара.
  - **Пускова «Фламінго»:** темна платформа на весь майданчик з облямівкою кольору гравця (як у ракетної шахти), відбійна стінка, рампа з ракетою і бункер керування.

## Що нового у версії 1.3.0

- **Оператор БПЛА б'є далі:** дальність FPV-дрона 7 клітинок (було 5) — як у Тесла-танка. Огляд оператора збільшено з 4 до 6 клітинок. Бункер дронів б'є, як і раніше, на 5 клітинок.
- **Новий дрон-камікадзе «Лютий»** (аеродром, потрібен український техцентр, 1500). Летить до цілі як літак і за 2,5 клітинки пікірує на неї. Пряме влучання в будівлю: 112500 урону — 75% будівельного центру (MCV, розгорнутого в базу); усі інші будівлі отримують стільки ж, тож електростанції, казарми, радар, техцентр, аеродром тощо руйнуються з першого влучання. По юнітах: танк (важкий танк, 60000) втрачає половину здоров'я, піхота на всіх 8 сусідніх клітинках (включно з діагоналями) гине, за 2 клітинки — лише поранена, далі урону немає. Як і справжній «Лютий» (бойова частина 50–75 кг, поршневий двигун, лише навігаційна камера), дрон має малий радіус вибуху по будівлях (повний урон до 0,5 клітинки, 50% на 0,75, 10% на 1,25), летить повільніше за Bayraktar TB2 і бачить лише 5 клітинок. Одноразовий; збитий в дорозі — падає без вибуху боєголовки.
- **Аеромобільний десант замість «Десанту» (парашутистів):** два гвинтокрили Мі-8 прилітають із боку вашої бази, сідають поруч у вказаному місці, висаджують 8 піхотинців (4 стрільці, 2 гранатометники, 2 оператори БПЛА), злітають і відлітають за край мапи. Перезарядка така сама, як у «Десанту», — 5 хвилин. Гвинтокрили можна збити, поки вони летять або стоять. Працює на всіх мапах для сутичок і мережевої гри (не в місіях кампанії, де фракції «Україна» й так немає).
- **Storm Shadow — одна точна ракета:** як справжня (проникна бойова частина 450 кг, наведення з точністю до кількох метрів, низький малопомітний політ), вона б'є в одну точку: 120000 урону тому, що стоїть у клітинці прицілу, майже без ураження довкола. Знищує будь-яку будівлю, крім будівельного центру й заводу (ті лишаються з 20%), будь-яку оборону чи ППО, танк або корабель; піхоту лише зачіпає. Ракету не можна перехопити, а супротивник не отримує попередження про пуск. Боти б'ють нею по найціннішій окремій будівлі.
- **«Богдана» з піднятим стволом:** 155-мм ствол тепер стоїть на станині на даху й піднятий над кабіною в бойове положення (кут близько 35°), пофарбований темним, тож його добре видно; постріл виходить з дульного гальма піднятого ствола.
- **F-16 — винищувач ППО:** як і в Україні, де F-16 насамперед боронять небо, він тепер озброєний ракетами повітря-повітря AIM-120 (дальність 9 клітинок — більше, ніж у ЗРК; два влучання збивають Як чи МіГ, три — Мі-24) і б'є лише по повітряних цілях. Стоїть у режимі оборони: сам злітає й перехоплює ворожу авіацію поблизу. Боти тримають F-16 біля бази як перехоплювачі.
- **Бот за Україну воює дронами.** Для української фракції бот має власну логіку виробництва (інші фракції не зачеплено) і насамперед будує:
  - піхоту: стрільці → оператори БПЛА → ракетники → інженери → агенти ГУР;
  - техніку: БТР-4 → «Вільха» → Gepard → «Булат» → «Ратель С» → «Оплот» → «Богдана» (плюс кілька мінних загороджувачів);
  - авіацію: Bayraktar TB2 (розвідка та удари) → «Лютий» → F-16 (тримає біля бази як ППО);
  - флот: Sea Baby → корвет.
  Бункер дронів бот ставить рано, бо без нього не відкриваються оператори БПЛА. Швидкий бот («rush») будує один аеродром (не раніше 4-ї хвилини) лише для двох Bayraktar TB2-розвідників.
- **Новий опис фракції:** «Ukraine: Drone Warfare» — дрони-камікадзе на суші, на морі й у повітрі.
- **Описи всієї української техніки, піхоти й споруд** переписано в стилі оригінального Red Alert: коротка роль юніта, далі «Strong vs / Weak vs / Special Ability».
- **Літак-розвідник (Spy Plane) прибрано** з українського аеродрому. У радянських фракцій усе без змін.
- **Полігон «UA Proving Ground»** (мапа в списку мод-мап): готова база з «Лютими», мішені для них, зона висадки Мі-8, оборона для Storm Shadow і мішені для операторів БПЛА; мішені відновлюються.

## Що нового у версії 1.2.1

- **Оператор БПЛА та агент ГУР** тепер намальовані на основі стандартного стрільця Red Alert, у тому ж стилі й з тими ж анімаціями, що вся піхота гри. Оператор має рюкзак-радіостанцію з довгою штировою та короткою тактичною антенами. Агент має темний шолом із ПНБ, білу маску-череп, темний плитоносець і глушник на автоматі.
- **Storm Shadow знову завдає урону.** Раніше всі три ракети падали за 2 клітинки від цілі, тож обрана ціль не отримувала нічого. Тепер перша ракета влучає в саму ціль, дві інші — по діагоналі позаду неї. Кожна б'є як одна парабомба: 30000, радіус 1 клітинка, ті самі модифікатори броні.
- **Башти «Булата», «Оплоту» та Gepard мають темну обводку**, як башта легкого танка Альянсу, тож їх добре видно на тлі корпусу.
- **Тінь від башти більше не перекриває корпус** у «Булата», «Оплоту», Gepard і БТР-4: як і в стокових танків, тінь дає лише корпус.
- **Скло без яскраво-синього кольору**: кабіни, вікна, приціли й екрани техніки, авіації, корвета та споруд намальовано тією ж приглушеною сіро-блакитною гамою, що й скло стокової техніки Red Alert.
- **Башта «Оплоту» за фото**: модулі ДЗ «Дуплет» сходяться стрілою до гармати, прямі вертикальні борти з рядом блоків ДЗ, кормова ніша з кошиком укладки; добре помітний зенітний кулемет, піднятий над командирською башточкою, з довгим темним стволом і світлою ствольною коробкою.
- **Нові моделі Gepard, «Вільхи», «Богдани» та БТР-4**, перероблені за фото в загальному стилі OpenRA. Gepard: шасі Leopard 1 без екранів (сім великих котків, ведуче колесо, лінивець), решітки моторного відсіку, коробчаста башта з круглою РЛС супроводу на лобі та великою овальною РЛС огляду на щоглі, корпуси двох 35-мм гармат з піднятими стволами, димові гранатомети. БТР-4: «човниковий» ніс, похиле лобове скло до пласкої даху, борти з нахиленою всередину верхньою частиною, жалюзі двигуна, чотири осі й бойовий модуль «Парус» за серединою корпусу; коли піхота сідає в машину, задні двері розчиняються, а потім зачиняються. «Вільха»: шасі МАЗ-543М з низьким переднім блоком (лобове скло, решітка, жалюзі двигуна) і високим відсіком розрахунку, чотири осі, пакет із 12 труб на шарнірі в самому кінці, піднятий для пуску. «Богдана 3.0» на шасі Tatra 815-7 у похідному положенні: гранована броньована кабіна й відсік за нею з жалюзі, платформа з високими бортами, драбина й похідний фіксатор ствола, гармата з великим кожухом на кормі, 155-мм ствол покладено вперед над дахом, сошник складено клином позаду.
- **Bayraktar TB2 глушить радари**, як мобільна радарна глушилка Альянсу: вимикає ворожі радари в радіусі 18 клітинок і відхиляє ворожі ракети в радіусі 5 клітинок.
- **Bayraktar TB2 виявляє замасковані юніти, міни й підводні човни** в радіусі 7 клітинок.
- **Боти будують до 4 пусків «Фламінго»** (раніше фактично лише один) і «Покрову». «Фламінго» бот спрямовує на найцінніше скупчення ворожих споруд і не б'є поруч зі своїми військами. «Покрову» бот вмикає лише там, де його юніти саме ведуть бій, а не на військо, що стоїть без діла.

## Що потрібно

- **OpenRA release-20250330** (Windows). Інші версії OpenRA не підтримуються.
- **Встановлений контент Red Alert.** Якщо звичайний Red Alert в OpenRA вже запускається й ви грали хоча б одну місію чи сутичку, контент є. Якщо ні, спершу запустіть звичайний Red Alert і дайте йому завантажити ігрові файли (гра запропонує це сама).

## Встановлення

1. Знайдіть теку, куди встановлено OpenRA. Зазвичай це `C:\Program Files\OpenRA`. У ній лежать `RedAlert.exe` і тека `mods`.
2. Розпакуйте архів мода **в цю теку**. Має вийти так:

   ```
   OpenRA\
     RedAlert.exe
     RedAlert-Ukraine.cmd     <- ярлик запуску мода
     mods\
       ra\                    <- звичайний Red Alert (не змінюється)
       ra-ukraine\            <- цей мод
   ```

   Якщо OpenRA стоїть у `Program Files`, Windows попросить підтвердити копіювання з правами адміністратора — це нормально.

## Запуск

- Двічі клацніть **`RedAlert-Ukraine.cmd`** у теці OpenRA.
- Або створіть ярлик на `RedAlert.exe` і в полі «Об'єкт» додайте в кінці ` Game.Mod=ra-ukraine`, наприклад:
  `"C:\Program Files\OpenRA\RedAlert.exe" Game.Mod=ra-ukraine`

Заголовок вікна має бути **«OpenRA - Red Alert: Ukraine»**. У лобі оберіть країну **Ukraine** (група Allies).

Звичайний Red Alert запускається, як і раніше, через `RedAlert.exe`.

## Гра по мережі

Усі гравці повинні мати **той самий мод тієї ж версії**, встановлений так само. Сервер, створений у моді, видно лише гравцям, які теж запустили мод.

## Видалення

Видаліть теку `mods\ra-ukraine` і файл `RedAlert-Ukraine.cmd`. Звичайний Red Alert і ваші налаштування залишаться без змін.

## Якщо щось не працює

| Проблема | Що зробити |
|---|---|
| Гра просить завантажити контент | Запустіть звичайний Red Alert і завершіть завантаження ігрових файлів, потім знову запустіть мод. |
| Відкривається звичайний Red Alert | Перевірте, що тека називається саме `ra-ukraine` і лежить у `OpenRA\mods`, а в ярлику є `Game.Mod=ra-ukraine`. |
| Гра одразу закривається | Перевірте версію OpenRA (потрібна release-20250330). Подробиці помилки — у `%APPDATA%\OpenRA\Logs\exception.log`. |
| Не вдається скопіювати файли в `Program Files` | Скопіюйте з правами адміністратора або встановіть OpenRA в іншу теку. |

---

## English (short)

**Red Alert: Ukraine** — a mod for OpenRA **release-20250330** that turns Ukraine into an Allied sub-faction equipped with Armed Forces of Ukraine hardware. It does not modify the stock Red Alert.

1. Make sure stock Red Alert runs in OpenRA (its game content must be installed).
2. Extract the archive into the OpenRA folder, so that `mods\ra-ukraine` sits next to `mods\ra`.
3. Start the mod with `RedAlert-Ukraine.cmd`, or run `RedAlert.exe Game.Mod=ra-ukraine`.
4. To uninstall, delete `mods\ra-ukraine` and `RedAlert-Ukraine.cmd`.

All multiplayer participants need the same mod version.

New in 1.4.1: a tactics script (scripts/ukraine-ai.lua) drives the units the stock bots cannot use well, on every skirmish map. All bots: APCs (BTR-4 for Ukraine) wait loaded at the barracks and go when there is a fight (an attack on the base, the army in the field); the infantry gets out next to enemy troops (7 cells) or any enemy building (9 cells), walks on to a close next target, and for a far one the APC drives up to its squad, picks it up and takes it there; when the enemy cannot be reached by land, bots build landing craft and land troops on a beach next to the enemy base that its defences do not cover (loaded APCs go aboard with their infantry; the rush bot now builds a naval yard too). Air defence (Gepard, Flak Truck, rocket soldier, destroyer, missile submarine, corvette Mazepa) switches from ground targets to enemy aircraft that come within reach, for players and bots alike. The Allies can build the APC; every faction, Ukraine included, has the landing craft. The Bayraktar TB2 no longer deflects missiles; the Ratel S now really attacks buildings (it could not reach the centre of a large building before) and takes half the full health off any building, so two of them destroy a Construction Yard (units are still destroyed in one hit). Ukrainian bots build more airfields and the script orders drones itself (the engine let a bot build an aircraft only for a free airfield, so the first TB2 or F-16 blocked every further drone): at least 3 TB2s and 2 Lyutyi drones (rush: 2 TB2s, no Lyutyi), spent Lyutyi drones are replaced; Bayraktar TB2s watch key points between the bases, strike targets that no air defence covers, leave air defence range at once and fly over enemy stealth units, mines and submarines near friendly forces to reveal them (the rush bot has two); Lyutyi drones (not the rush bot) strike scouted buildings in salvoes, the valuable and least defended first; Ratel S hunt enemy vehicles near the base and the troops, and sneak around base defences in pairs to blow up buildings; Sea Babies attack ships and naval yards in groups (they can now hit naval yards, and they no longer fail against a ship that stands still); UAV operators are built a little more often than riflemen; HUR agents slip around the defences to the refinery or silo of the richest enemy, killing infantry on the way, and steal valuable vehicles they meet; the Mi-8 air assault lands next to the enemy base, away from air defence and base defences; Bohdana and Vilkha stay 7-8 cells behind the leading unit of the army; F-16s intercept enemy aircraft near the base and the troops. Defences and superweapons are redrawn in the style of the stock Red Alert structures (compact, team-colour surfaces, no outlines): the Stugna-P is an octagonal plinth with a steel deck and the launcher on a tripod, with the team colour where the Soviet SAM Site has it (a band along the foot and a chevron on the deck); the Drone Bunker is a low octagonal bunker whose roof hatch opens to let an FPV drone out at every launch; the Pokrova station is a phased-array radar (a truncated pyramid with cut corners and a big round antenna array on each face, on a hall with a broad team-colour band, in the colours and textures of the stock Radar Dome) and a blue beam rises from it for a few seconds when it is activated; the Flamingo launch position is a dark platform with a team-colour band, blast deflector, ramp and control bunker.

New in 1.3.0: the UAV operator's FPV drone reaches 7 cells like the Tesla Tank (was 5) and the operator sees 6 cells; new Lyutyi kamikaze drone from the airfield (needs the Ukrainian Tech Center): slow and short-sighted like the real one, with a small warhead: it dives onto its target, takes 75% off a Construction Yard, destroys smaller buildings in one hit, takes half the health of a tank and kills the infantry in all cells around the impact; the Paratroopers power of the Ukrainian airfield is replaced by a Mi-8 air assault with the same 5-minute recharge (two helicopters land at the target, unload 8 infantry and fly away); the Storm Shadow strike is now one precision missile with a penetrating warhead: a point strike that destroys the single building (a Construction Yard or War Factory is left at 20%), defence, vehicle or ship it hits, cannot be intercepted and gives the enemy no warning; the AI aims it at the most valuable enemy structure; the Bohdana's 155 mm barrel sits on a roof mount, raised over the cab (about 35 degrees) and painted dark so it is easy to see; the F-16 becomes an air-superiority fighter: AIM-120 air-to-air missiles (9 cells, more than a SAM Site), air targets only, on the Defend stance it scrambles against enemy aircraft by itself, and AI players keep it home as an interceptor; Ukrainian bots get their own production logic built around drones (riflemen, UAV operators, BTR-4, Vilkha, Gepard, Bulat, Ratel S; TB2 and Lyutyi in the air, F-16 kept home as interceptors; Sea Baby at sea) and build the Drone Bunker early; the rush bot builds one airfield, only for two TB2 scouts; the faction is now described as "Ukraine: Drone Warfare"; all Ukrainian unit and building descriptions are rewritten in the stock Red Alert style; the Ukrainian airfield no longer has the Spy Plane; new "UA Proving Ground" map to try all of it.

New in 1.2.1: the UAV operator and HUR agent are now the stock Red Alert rifleman with their kit painted on (manpack radio and antennas; night vision, skull balaclava, plate carrier, suppressor); the Storm Shadow strike damages its target again (the lead missile hits the aim cell, each missile hits as hard as one parabomb); the Bulat, Oplot and Gepard turrets have a dark rim like the Allied Light Tank turret; the turret shadow of the Bulat, Oplot, Gepard and BTR-4 no longer covers the hull; glass (cockpits, windows, sights, screens) uses the stock Red Alert glass colours instead of bright blue; the Oplot turret is reshaped after a reference photo (Duplet arrowhead front, straight ERA-lined sides, rear basket) and its AA machine gun is raised and enlarged so it is easy to see; new Gepard (Leopard 1 chassis with open running gear, round tracking and oval search radars, raised twin 35 mm guns), BTR-4 (boat bow, sloped windscreen, Parus module behind the middle; its rear doors swing open while infantry climb in), Vilkha (MAZ-543M chassis, raised 12-tube pack) and Bohdana 3.0 (Tatra 815-7 chassis, faceted armoured cab, 155 mm barrel laid forward over the roof) models drawn after reference photos; the Bayraktar TB2 jams enemy radar and deflects missiles like the Allied Mobile Radar Jammer, and detects cloaked units, mines and submarines within 7 cells; AI players build up to 4 Flamingo pads, aim the Flamingo at enemy structures away from their own troops, and drop the Pokrova field only on their own units that are in a fight.
