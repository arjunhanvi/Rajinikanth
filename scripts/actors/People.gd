class_name People
extends RefCounted
## The cast. Every named character has an identity, an occupation, a home, a
## daily schedule, friends and things to say. All characters are fictional.

## The named cast below belongs to the retired RAJINIKANTH story (archived in
## archive/rajinikanth/). BIG BANG LORE does not spawn them.
const LEGACY_CAST := false

const NAMES := {
	"nanjappa": "Nanjappa", "meena": "Meenakshi", "uma": "Umashankar", "kamakshi": "Kamakshi", "devaraj": "Devaraj", "immu": "Imtiaz",
	"girija": "Girija", "putti": "Putti", "lokesh": "S.I. Lokesh", "shivaramu": "Inspector Shivaramu", "tiger": "'Tiger' Thimmaiah",
	"oilkumar": "'Oil' Kumar", "soda": "'Soda' Anthony", "pinto": "Pinto", "channanna": "M.L.A. Channanna", "vicky": "Vicky",
	"vasantha": "Vasantha Kumari", "shalini": "Shalini Rao", "subbu": "Subbu", "mohan": "Advocate Mohan Rao", "shwetha": "Shwetha",
	"lakshmamma": "Lakshmamma", "rafiq": "Master Rafiq", "balaji": "Balaji", "bhatta": "Bhatta", "mani": "Mani", "chotu": "Raju",
	"phone": "Unknown number", "raji": "Rajinikanth",
}

# sched: [hour, place id, mode]  mode: in = at their post, at = standing about, sit = seated nearby, off = indoors / away
# walk: [stride, sway, arm swing, lean] personal gait.  voice: pitch of their speech blips.
const DB := {
	"uma": {"role": "Driver, Route 27E. Your best friend since the depot canteen, 1991.", "job": "driver", "sex": 0, "home": "uma_home",
		"family": "Wife Girija, daughter Putti (8th Standard), mother in Tumkur.", "money": "Always ten days short of salary day.", "walk": [0.82, 1.9, 0.7, 0.04], "voice": 0.8,
		"look": {"skin": 3, "hair": 5, "hair_col": 0, "beard": 2, "top": 7, "top_col": 1, "bottom": 0, "bot_col": 1, "build": 1.0, "fat": 1.0, "height": 0.42, "face": 1, "acc": 0, "shoes": 0, "age": 0.45, "watch": 3},
		"sched": [[0, "uma_home", "off"], [5.6, "majestic", "at"], [13.0, "tea", "sit"], [14.0, "majestic", "at"], [20.5, "tea", "sit"], [21.6, "uma_home", "off"]], "friends": ["nanjappa", "immu"]},
	"kamakshi": {"role": "Your wife. Advocate, High Court of Karnataka. From Srirangam.", "job": "advocate", "sex": 1, "home": "home",
		"family": "Parents in Srirangam; a brother in the Railways.", "money": "Earns more than you. Has never once said so.", "walk": [1.05, 0.7, 0.8, -0.02], "voice": 1.25,
		"look": {"skin": 1, "hair": 8, "hair_col": 0, "top": 8, "top_col": 0, "bottom": 4, "bot_col": 3, "build": 0.35, "height": 0.62, "face": 4, "acc": 0, "glasses": 0, "age": 0.36, "watch": 1},
		"sched": [[0, "home", "off"], [7.0, "home", "at"], [9.6, "court", "at"], [13.2, "darshini", "at"], [14.0, "court", "at"], [17.6, "home", "at"], [21.5, "home", "off"]], "friends": ["mohan", "shalini"]},
	"devaraj": {"role": "Finance, travels, real estate, a rolling mill. Chairman of three temple committees.", "job": "boss", "sex": 0, "home": "devaraj",
		"family": "Wife Sumithra, a son in Manipal, a nephew he calls 'my headache'.", "money": "Nobody knows. That is the point.", "walk": [0.9, 0.6, 0.45, -0.05], "voice": 0.7,
		"look": {"skin": 2, "hair": 1, "hair_col": 2, "beard": 2, "top": 6, "top_col": 0, "bottom": 0, "bot_col": 0, "build": 0.75, "height": 0.6, "glasses": 1, "watch": 2, "acc": 1, "shoes": 1, "age": 0.62, "face": 2, "tilak": 1},
		"sched": [[0, "devaraj", "off"], [10.0, "devaraj", "at"], [13.0, "devaraj", "off"], [16.0, "devaraj", "at"], [19.5, "temple", "at"], [20.5, "devaraj", "off"]], "friends": ["channanna", "lokesh"]},
	"girija": {"role": "Umashankar's wife. Runs the house on arithmetic and prayer.", "job": "housewife", "sex": 1, "home": "uma_home", "family": "Married to Umashankar.", "walk": [0.9, 1.1, 0.6, 0.0], "voice": 1.2,
		"look": {"skin": 3, "hair": 8, "top": 8, "top_col": 5, "bottom": 4, "bot_col": 10, "build": 0.7, "height": 0.35, "acc": 5, "age": 0.42},
		"sched": [[0, "uma_home", "off"], [6.5, "uma_home", "at"], [9.0, "uma_home", "off"], [16.5, "uma_home", "at"], [19.0, "uma_home", "off"]], "friends": ["lakshmamma"]},
	"putti": {"role": "Umashankar's daughter. Eighth Standard. First in class, and knows it.", "job": "student", "sex": 1, "home": "uma_home", "family": "Umashankar and Girija's daughter.", "walk": [1.1, 1.0, 1.2, 0.0], "voice": 1.5,
		"look": {"skin": 3, "hair": 7, "top": 9, "top_col": 2, "bottom": 5, "bot_col": 0, "build": 0.2, "height": 0.4, "acc": 6, "age": 0.05},
		"sched": [[0, "uma_home", "off"], [7.4, "uma_home", "at"], [8.0, "uma_home", "off"], [16.6, "uma_home", "at"], [18.5, "uma_home", "off"]], "friends": []},
	"nanjappa": {"role": "Tea stall owner. Knows everything, says half.", "job": "vendor", "sex": 0, "home": "tea", "family": "A son in Dubai who sends photographs, not money.", "walk": [0.85, 1.0, 0.6, 0.08], "voice": 0.85,
		"look": {"skin": 4, "hair": 3, "hair_col": 2, "beard": 2, "top": 10, "top_col": 0, "bottom": 2, "bot_col": 4, "acc": 3, "build": 0.7, "shoes": 0, "age": 0.7},
		"sched": [[0, "tea", "off"], [5.4, "tea", "in"], [21.6, "tea", "off"]], "friends": ["uma", "lakshmamma"]},
	"meena": {"role": "Runs the S.T.D. booth. Hears the whole city's secrets.", "job": "booth", "sex": 1, "home": "std", "family": "Lives with her father, a retired postman.", "walk": [1.0, 0.9, 0.9, 0.0], "voice": 1.3,
		"look": {"skin": 2, "hair": 7, "top": 9, "top_col": 11, "bottom": 5, "bot_col": 0, "acc": 5, "build": 0.3, "height": 0.45, "face": 5, "age": 0.25},
		"sched": [[0, "std", "off"], [8.8, "std", "in"], [13.0, "darshini", "at"], [13.7, "std", "in"], [20.5, "std", "off"]], "friends": ["shalini"]},
	"immu": {"role": "Auto driver. Knows every lane God forgot.", "job": "auto", "sex": 0, "home": "uma_home", "family": "Four sisters. Three married off. He is tired.", "walk": [1.0, 1.2, 1.1, 0.02], "voice": 1.0,
		"look": {"skin": 3, "hair": 2, "beard": 5, "top": 7, "top_col": 1, "bottom": 0, "bot_col": 1, "build": 0.5, "acc": 0, "shoes": 0, "age": 0.35},
		"sched": [[0, "uma_home", "off"], [7.0, "police", "at"], [13.0, "darshini", "at"], [14.0, "railway", "at"], [19.0, "tea", "sit"], [22.0, "uma_home", "off"]], "friends": ["uma"]},
	"lokesh": {"role": "Sub-Inspector, Upparpet. His salary is a rumour.", "job": "police", "sex": 0, "home": "police", "family": "A wife who wears more gold every Deepavali.", "walk": [0.95, 0.8, 0.5, -0.06], "voice": 0.75,
		"look": {"skin": 2, "hair": 0, "beard": 3, "top": 1, "top_col": 1, "bottom": 0, "bot_col": 1, "build": 0.85, "glasses": 2, "acc": 2, "shoes": 1, "watch": 2, "age": 0.45},
		"sched": [[0, "police", "in"], [13.0, "darshini", "at"], [14.0, "police", "in"], [21.0, "bar", "at"], [23.0, "police", "in"]], "friends": ["devaraj"]},
	"shivaramu": {"role": "Inspector. Tired, honest, three years from pension.", "job": "police", "sex": 0, "home": "police", "family": "A daughter studying law. He is proud and worried.", "walk": [0.85, 0.8, 0.6, 0.06], "voice": 0.8,
		"look": {"skin": 3, "hair": 3, "hair_col": 2, "beard": 2, "top": 1, "top_col": 1, "bottom": 0, "bot_col": 1, "build": 0.6, "acc": 2, "shoes": 1, "age": 0.75},
		"sched": [[0, "police", "off"], [10.0, "police", "at"], [18.0, "police", "off"]], "friends": []},
	"tiger": {"role": "Flower merchant. Also other things.", "job": "don", "sex": 0, "home": "godown", "family": "Two wives, one will. Everyone is waiting.", "walk": [0.8, 0.7, 0.4, -0.04], "voice": 0.65,
		"look": {"skin": 4, "hair": 2, "hair_col": 2, "beard": 3, "top": 5, "top_col": 0, "bottom": 3, "bot_col": 0, "build": 0.95, "acc": 1, "watch": 2, "height": 0.7, "face": 2, "age": 0.68},
		"sched": [[0, "godown", "off"], [5.0, "godown", "at"], [23.0, "godown", "off"]], "friends": ["oilkumar"]},
	"oilkumar": {"role": "Thimmaiah's right hand. Named for what he once sold.", "job": "goon", "sex": 0, "home": "godown", "family": "None he admits to.", "walk": [1.1, 1.3, 1.2, -0.03], "voice": 0.9,
		"look": {"skin": 5, "hair": 5, "beard": 5, "top": 2, "top_col": 4, "bottom": 2, "bot_col": 3, "build": 0.9, "acc": 1, "height": 0.8, "age": 0.4},
		"sched": [[0, "godown", "at"], [20.0, "bar", "at"], [23.5, "godown", "at"]], "friends": ["tiger"]},
	"soda": {"role": "Video parlours in the Cantonment, and a smile.", "job": "don", "sex": 0, "home": "parlour", "family": "A mother he visits every Sunday after Mass.", "walk": [1.0, 0.8, 0.9, -0.02], "voice": 1.0,
		"look": {"skin": 1, "hair": 1, "beard": 6, "top": 6, "top_col": 0, "bottom": 0, "bot_col": 0, "build": 0.45, "glasses": 2, "acc": 1, "watch": 2, "shoes": 1, "face": 4, "age": 0.42},
		"sched": [[0, "parlour", "off"], [11.0, "parlour", "at"], [20.0, "pub", "at"], [23.9, "parlour", "off"]], "friends": []},
	"pinto": {"role": "Collection agent, Sri Devaraj Finance. Polite until he is not.", "job": "goon", "sex": 0, "home": "devaraj", "family": "Sends money to Mangalore every month, on time.", "walk": [1.05, 1.0, 1.0, -0.04], "voice": 0.9,
		"look": {"skin": 2, "hair": 0, "beard": 4, "top": 4, "top_col": 8, "bottom": 1, "build": 0.8, "acc": 1, "shoes": 2, "age": 0.33},
		"sched": [[0, "devaraj", "off"], [10.0, "devaraj", "at"], [19.0, "bar", "at"], [22.5, "devaraj", "off"]], "friends": ["devaraj"]},
	"vicky": {"role": "Devaraj's nephew. B.B.M. (ongoing, sixth year).", "job": "idle", "sex": 0, "home": "devaraj", "family": "Devaraj's sister's son.", "walk": [1.15, 1.4, 1.3, -0.08], "voice": 1.1,
		"look": {"skin": 1, "hair": 4, "beard": 6, "top": 2, "top_col": 13, "bottom": 1, "build": 0.4, "glasses": 2, "acc": 1, "shoes": 2, "watch": 2, "age": 0.2, "height": 0.7},
		"sched": [[0, "devaraj", "off"], [12.0, "cinema", "at"], [16.0, "devaraj", "at"], [19.0, "pub", "at"], [23.5, "devaraj", "off"]], "friends": []},
	"channanna": {"role": "M.L.A., Janata Pragathi Paksha. Lantern symbol.", "job": "neta", "sex": 0, "home": "jpp", "family": "A son-in-law on every committee.", "walk": [0.8, 0.9, 0.5, -0.06], "voice": 0.7,
		"look": {"skin": 3, "hair": 3, "hair_col": 3, "beard": 2, "top": 5, "top_col": 0, "bottom": 3, "bot_col": 0, "build": 1.0, "acc": 3, "watch": 2, "shoes": 4, "age": 0.7},
		"sched": [[0, "jpp", "off"], [9.5, "jpp", "at"], [17.0, "majestic", "at"], [19.0, "jpp", "at"], [21.0, "jpp", "off"]], "friends": ["devaraj"]},
	"vasantha": {"role": "Corporator, K.N.V. Plough symbol. Means it, mostly.", "job": "neta", "sex": 1, "home": "knv", "family": "Widowed. The ward is her family, she says, and sometimes it is true.", "walk": [1.0, 0.7, 0.8, 0.0], "voice": 1.1,
		"look": {"skin": 2, "hair": 8, "hair_col": 1, "top": 8, "top_col": 0, "bottom": 4, "bot_col": 5, "build": 0.5, "glasses": 1, "acc": 0, "face": 3, "age": 0.6},
		"sched": [[0, "knv", "off"], [9.0, "knv", "at"], [20.0, "knv", "off"]], "friends": ["kamakshi"]},
	"shalini": {"role": "Crime reporter, Sanje Vaani. Asks the second question.", "job": "press", "sex": 1, "home": "paper", "family": "Shares a room in Basavanagudi with two other working women.", "walk": [1.15, 0.8, 1.0, -0.03], "voice": 1.3,
		"look": {"skin": 1, "hair": 8, "top": 9, "top_col": 2, "bottom": 5, "bot_col": 0, "build": 0.3, "glasses": 3, "acc": 6, "height": 0.55, "face": 4, "age": 0.28},
		"sched": [[0, "paper", "off"], [10.0, "paper", "at"], [13.0, "darshini", "at"], [14.0, "police", "at"], [17.0, "paper", "at"], [21.0, "paper", "off"]], "friends": ["kamakshi"]},
	"mohan": {"role": "Kamakshi's senior at the Bar. Forty years of adjournments.", "job": "advocate", "sex": 0, "home": "court", "family": "Three generations of advocates and one disappointing dentist.", "walk": [0.8, 0.7, 0.5, 0.08], "voice": 0.75,
		"look": {"skin": 2, "hair": 3, "hair_col": 3, "beard": 0, "top": 11, "top_col": 8, "bottom": 0, "bot_col": 8, "build": 0.6, "glasses": 1, "shoes": 1, "age": 0.85},
		"sched": [[0, "court", "off"], [10.0, "court", "at"], [17.0, "court", "off"]], "friends": ["kamakshi"]},
	"lakshmamma": {"role": "Owns Lakshmi Vatara. The rent is due. It is always due.", "job": "landlady", "sex": 1, "home": "uma_home", "family": "Outlived a husband and two tenants' excuses.", "walk": [0.75, 1.3, 0.5, 0.1], "voice": 1.0,
		"look": {"skin": 3, "hair": 8, "hair_col": 2, "top": 8, "top_col": 4, "bottom": 4, "bot_col": 6, "build": 0.9, "acc": 0, "height": 0.3, "age": 0.8},
		"sched": [[0, "uma_home", "off"], [6.0, "uma_home", "at"], [10.0, "tea", "at"], [11.0, "uma_home", "at"], [20.0, "uma_home", "off"]], "friends": ["nanjappa", "girija"]},
	"rafiq": {"role": "Tailor. Measures you with one look.", "job": "tailor", "sex": 0, "home": "tailor", "family": "Five children, all of whom can hem.", "walk": [0.85, 0.8, 0.6, 0.08], "voice": 0.9,
		"look": {"skin": 2, "hair": 3, "hair_col": 2, "beard": 5, "top": 5, "top_col": 0, "bottom": 0, "bot_col": 12, "glasses": 3, "acc": 2, "build": 0.4, "age": 0.7},
		"sched": [[0, "tailor", "off"], [9.5, "tailor", "in"], [21.0, "tailor", "off"]], "friends": []},
	"balaji": {"role": "Second-hand vehicles. First-hand lies.", "job": "dealer", "sex": 0, "home": "dealer", "family": "A brother-in-law in the R.T.O., which explains a lot.", "walk": [1.0, 1.1, 1.0, -0.03], "voice": 1.0,
		"look": {"skin": 3, "hair": 2, "beard": 2, "top": 2, "top_col": 6, "bottom": 0, "bot_col": 8, "build": 0.8, "acc": 1, "watch": 2, "shoes": 1, "age": 0.45},
		"sched": [[0, "dealer", "off"], [9.5, "dealer", "in"], [20.5, "dealer", "off"]], "friends": []},
	"bhatta": {"role": "Cashier, Hotel Dwaraka. Tokens first.", "job": "cashier", "sex": 0, "home": "darshini", "family": "From Udupi, like the sambar.", "walk": [0.9, 0.9, 0.6, 0.0], "voice": 0.95,
		"look": {"skin": 2, "hair": 6, "beard": 0, "top": 0, "top_col": 0, "bottom": 3, "bot_col": 0, "build": 0.7, "acc": 3, "age": 0.55, "tilak": 1},
		"sched": [[0, "darshini", "off"], [6.0, "darshini", "in"], [22.0, "darshini", "off"]], "friends": []},
	"mani": {"role": "Waiter, Kaveri Bar. Remembers every order and every debt.", "job": "waiter", "sex": 0, "home": "bar", "family": "Sleeps in the store room; saving for a sister's wedding.", "walk": [1.1, 0.9, 0.9, 0.0], "voice": 1.1,
		"look": {"skin": 4, "hair": 1, "beard": 1, "top": 0, "top_col": 0, "bottom": 0, "bot_col": 8, "build": 0.3, "age": 0.25},
		"sched": [[0, "bar", "off"], [11.0, "bar", "in"], [23.5, "bar", "off"]], "friends": []},
}

const CHAT := {
	"uma": ["Thirty kilos ago I could reverse this bus into a matchbox. Now the matchbox has to be bigger, that's all.", "Girija says I should eat less. I said, then who will finish Putti's leftover upma? Wastage is a sin.",
		"A bus is like a marriage, Raji. Don't brake suddenly and nobody gets hurt.", "You're thinking again. I can hear it from here. Stop it and check the ticket roll."],
	"kamakshi": ["I have a matter before the Division Bench at eleven. If you get arrested again, kindly do it after lunch.", "In Srirangam nobody locks their doors. In Bangalore I married a man who got locked in by the State.",
		"You look at the ground when you lie, Rajini. Eleven years. I have a chart.", "Eat something. Not at that Nanjappa's. Something with a vegetable in it."],
	"devaraj": ["Sit, sit. In this office nobody stands except the people who owe me.", "I am a simple businessman. Simple things: land, loans, loyalty.", "Your wife argues very well. I admire education in a woman. Up to a point."],
	"girija": ["He told you about the school fees? He tells everybody. Only the school he doesn't tell.", "Eat before you go. You're thin. Jail didn't feed you or what."],
	"putti": ["Rajini uncle! Appa said you were on 'official duty out of station'. I'm thirteen, not three.", "Kamakshi aunty said I can be a lawyer. Appa said first be on time for the school bus."],
	"nanjappa": ["By-two coffee? Or are you a full-cup man today?", "Devaraj's finance boys came for 'festival collection'. Which festival, I asked. They said, yours.", "Tea is two rupees. Advice is free. Guess which one people take.",
		"Umashankar had four buns and said he's dieting. I didn't argue. He's a big man."],
	"meena": ["Local call one rupee. S.T.D. after ten o'clock is half rate.", "People think the glass on this booth is soundproof. It is not.", "Your wife called the station from here three times that week. She never raised her voice. That's how I knew she was furious."],
	"immu": ["Meter is one-and-a-half after ten, saar. For you, only one-and-a-quarter.", "Three policemen, one auto, no fare. That's called public service.", "You want to go somewhere? I know every lane God forgot."],
	"lokesh": ["Conductor. Stand properly when you talk to the department.", "This city runs on adjustments. I am the adjustment.", "Bail is not acquittal. Remember that when you walk past my station."],
	"shivaramu": ["If you have something to report, report it. If not, go home safely.", "I read your file. Some files are written before the incident. I can say no more."],
	"tiger": ["Flowers die in a day. That is why the business never stops.", "Sit. In my godown even enemies get coffee first."],
	"oilkumar": ["Anna doesn't like waiting. I like it even less.", "You have honest eyes. Bad for you."],
	"soda": ["Everybody rents, my friend. Videos, houses, people.", "Thimmaiah is the past. Devaraj thinks he is the future. I am the present, and I am patient."],
	"pinto": ["Sri Devaraj Finance. Easy instalments. The instalments are easy, I mean. Missing them is not.", "You're the ticket man. I remember faces. Also addresses."],
	"vicky": ["Do you know who my uncle is? ...Of course you do. Everybody does.", "Nice uniform. They gave it back to you, ah?"],
	"channanna": ["The lantern lights every poor man's house! ...Which channel are you from? Oh. Then move.", "Young man, in politics there are no enemies. Only future friends and current expenses."],
	"vasantha": ["Do you know how many street lights work in this ward? I counted. Eleven.", "Your wife drafted our petition against the Peenya acquisition. For free. Tell her the ward remembers."],
	"shalini": ["Off the record? Nothing is off the record. But I can spell your name wrong if you like.", "I do the crime page. It's the only page where nobody lies about their age."],
	"mohan": ["Kamakshi is the best junior I have had in forty years. Do not tell her. It will affect her preparation.", "Young man, the law is slow so that the truth can catch up. Sometimes the truth takes an auto."],
	"lakshmamma": ["Rent. And tell that Umashankar the staircase is not load-tested for him.", "First of the month means first of the month, not 'first week, Lakshmamma'."],
	"rafiq": ["Stand straight. Hm. Conductor's shoulders. Bag on the left since many years, no?", "Terry-cot or pure cotton? Don't say 'anything'. Nobody wears 'anything'."],
	"balaji": ["Single owner, doctor driven, only to temple and back.", "Finance? Devaraj Finance, next lane. Tell them Balaji sent you. Actually don't."],
	"bhatta": ["Token first, then eat. Next!", "Extra sambar is not a right. It is a relationship."],
	"mani": ["Usual? ...You don't have a usual. I'll decide.", "That table in the corner, don't look. Finance people."],
}

const FIRST_M := ["Ramesh", "Suresh", "Manju", "Venkatesh", "Ravi", "Prakash", "Girish", "Naveen", "Shankar", "Mahesh", "Salim", "Joseph", "Murthy", "Gopal", "Raghu", "Umesh", "Faiz", "Anand", "Kumar", "Dinesh", "Lingaraju", "Shivu", "Anthony", "Babu"]
const FIRST_F := ["Lakshmi", "Savitri", "Geetha", "Padma", "Roopa", "Shanthi", "Kavitha", "Fathima", "Mary", "Sudha", "Vani", "Asha", "Bhagya", "Nirmala", "Yasmin", "Latha", "Pushpa", "Rekha"]
const LAST := ["Gowda", "Rao", "Shetty", "Murthy", "Reddy", "Naidu", "Khan", "D'Souza", "Hegde", "Iyengar", "Swamy", "Kumar", "Pasha", "Acharya", "Nayak", "Bhat"]
const JOBS := {
	"com": ["shop assistant", "clerk", "salesman", "hawker", "office boy", "student", "coolie", "bank teller"],
	"old": ["flower seller", "coolie", "wholesale trader", "tailor", "goldsmith", "hawker", "priest"],
	"res": ["schoolteacher", "student", "retired clerk", "housewife", "milkman", "bank teller", "LIC agent"],
	"ind": ["lathe operator", "factory hand", "supervisor", "welder", "lorry cleaner"],
	"cant": ["retired colonel's driver", "college student", "nurse", "bakery man", "piano teacher"],
	"gov": ["government clerk", "typist", "advocate", "peon", "petition writer"],
	"out": ["farmer", "mason", "milkman", "tractor driver", "student"],
}
const SMALLTALK := [
	"What traffic, saar. Ten years back you could cross this road reading a newspaper.",
	"Did you see the match? Chasing three hundred at Lord's! I didn't sleep.",
	"Current went three times yesterday. They call this Silicon City.",
	"Everything is two rupees more this year. Except salaries.",
	"They say an I.T. company will come here too. Then where will we people go?",
	"Benki Basava is running housefull at Sangam. I saw it twice. Don't tell my wife.",
	"Cauvery water came for one hour this morning. One hour! We are fish or what?",
	"Election is coming. Suddenly every pothole has a foundation stone.",
	"This weather is why nobody leaves Bangalore. This traffic is why everybody wants to.",
	"My son says he will learn computers. I said first learn to wake up.",
]
const BY_JOB := {
	"coolie": "Luggage, saar? Twenty rupees. Okay, fifteen. Okay, you carry.",
	"hawker": "Fresh, fresh! Ten rupees. For you eight. Okay six, take.",
	"student": "Exams next week and the current keeps going. I'm studying under the street light like a film hero.",
	"flower seller": "Jasmine, one mola five rupees. Thimmaiah's godown sets the price, not me.",
	"priest": "Everything is written. Still, look both sides before crossing.",
	"government clerk": "Come tomorrow. No, I'm not at work now. Even then, come tomorrow.",
	"advocate": "Any small case? Site dispute? Cheque bounce? Take my card.",
	"factory hand": "Second shift. Shetty's place. Don't ask about the overtime.",
	"schoolteacher": "Thirty years I told children honesty pays. Then they see who has the cars.",
	"housewife": "Vegetables at K.R. Market are cheaper, but the bus fare eats the saving.",
	"bank teller": "Counter closes at two. People come at one fifty-nine with a gunny bag of coins.",
	"retired clerk": "I used to know this city. Now I know only this bench.",
}

# what named people are doing while at their post
const ACT := {"nanjappa": "pour", "bhatta": "work", "rafiq": "work", "mani": "work", "meena": "work", "balaji": "read", "lokesh": "read", "shalini": "listen", "lakshmamma": "sweep", "girija": "sweep", "kamakshi": "read", "mohan": "read", "devaraj": "phone"}

## Clothing category for an occupation (see Human.random_look).
static func look_cat(job: String) -> String:
	if job in ["student", "college student"]: return "student"
	if job in ["clerk", "salesman", "bank teller", "government clerk", "typist", "advocate", "supervisor", "LIC agent", "schoolteacher", "office boy"]: return "office"
	if job in ["hawker", "flower seller", "milkman", "wholesale trader", "bakery man"]: return "vendor"
	if job in ["lathe operator", "factory hand", "welder", "lorry cleaner", "mason", "tractor driver"]: return "mechanic"
	if job == "coolie": return "coolie"
	if job == "priest": return "priest"
	if job in ["retired clerk", "farmer"]: return "elder"
	if job in ["housewife"]: return "shopper"
	return ""

static func role(id: String) -> String:
	return DB[id].role if DB.has(id) else ""

static func look_of(id: String) -> Dictionary:
	var L := Human.default_look()
	var d: Dictionary = DB[id]
	L.sex = d.sex
	L.acc = 0
	L.watch = 0
	L.glasses = 0
	if int(d.sex) == 1:
		L.beard = 0
		L.shoes = 4
	for k in d.look:
		L[k] = d.look[k]
	if id in Human.HEROES:
		L["model"] = id
	return L

## Where a named character should be at a given hour: [place id, mode]
static func slot(id: String, hour: float) -> Array:
	var sch: Array = DB[id].sched
	var cur: Array = sch[0]
	for e in sch:
		if hour >= float(e[0]):
			cur = e
	return [cur[1], cur[2]]

static func random_identity(rng: RandomNumberGenerator, kind: String) -> Dictionary:
	var sex := 1 if rng.randf() < 0.36 else 0
	var first: String = FIRST_F[rng.randi() % FIRST_F.size()] if sex == 1 else FIRST_M[rng.randi() % FIRST_M.size()]
	var jobs: Array = JOBS.get(kind, JOBS["com"])
	var job: String = jobs[rng.randi() % jobs.size()]
	if sex == 1 and job in ["coolie", "lorry cleaner", "milkman", "tractor driver", "priest", "office boy", "salesman", "retired colonel's driver", "bakery man", "peon"]:
		job = "housewife" if rng.randf() < 0.5 else "schoolteacher"
	var hr := float(Game.s.get("time", 12.0))
	if (hr > 7.0 and hr < 9.5) or (hr > 15.5 and hr < 17.0):
		if rng.randf() < 0.3:
			job = "student"
	return {"name": "%s %s" % [first, LAST[rng.randi() % LAST.size()]], "job": job, "sex": sex, "mood": rng.randf()}

static func ambient_line(ident: Dictionary, rng: RandomNumberGenerator) -> String:
	var t := float(Game.s.time)
	var opts: Array = []
	if BY_JOB.has(ident.job):
		opts.append(BY_JOB[ident.job])
		opts.append(BY_JOB[ident.job])
	if Game.s.weather == "rain":
		opts.append("This rain! The whole road will be a lake by evening.")
	if t >= 21.5 or t < 5.5:
		opts.append("Last bus is gone. Decent people are at home, and we are here.")
	if int(Game.s.rep) >= 30:
		opts.append("You're... no, nothing. I didn't see anything, anna. Good day.")
	elif int(Game.s.stats.tickets) > 10 and Game.s.mode == "story":
		opts.append("Aren't you the conductor on 27E? You gave me a torn five-rupee note last week.")
	if float(Game.s.heat) > 20.0:
		opts.append("Police are asking around about somebody. I told them I mind my own business.")
	var lead := "JPP" if float(Game.s.politics.jpp) >= float(Game.s.politics.knv) else "KNV"
	opts.append("They say %s is ahead this time. They said that last time also." % lead)
	for i in 3:
		opts.append(SMALLTALK[rng.randi() % SMALLTALK.size()])
	return opts[rng.randi() % opts.size()]
