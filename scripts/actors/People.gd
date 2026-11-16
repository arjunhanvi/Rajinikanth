class_name People
extends RefCounted
## The cast. Every named character has an identity, an occupation, a home, a
## daily schedule, friends and things to say. All characters are fictional.

const NAMES := {
	"nanjappa": "Nanjappa", "meena": "Meenakshi", "basanna": "Basavaraju", "kitty": "Kitty", "immu": "Imtiaz",
	"seena": "Seena", "lokesh": "S.I. Lokesh", "shivaramu": "Inspector Shivaramu", "tiger": "'Tiger' Thimmaiah",
	"oilkumar": "'Oil' Kumar", "soda": "'Soda' Anthony", "pinto": "Pinto", "channanna": "M.L.A. Channanna",
	"vasantha": "Vasantha Kumari", "shetty": "Raghavendra Shetty", "shalini": "Shalini Rao", "subbu": "Subbu",
	"lakshmamma": "Lakshmamma", "rafiq": "Master Rafiq", "balaji": "Balaji", "bhatta": "Bhatta", "mani": "Mani",
	"phone": "Unknown number", "raji": "Rajinikanth",
}

# sched: [hour, place id, mode]  mode: in = behind the counter, at = standing about, sit = seated nearby
const DB := {
	"nanjappa": {"role": "Tea stall owner. Knows everything, says half.", "job": "vendor", "sex": 0, "home": "tea",
		"look": {"skin": 4, "hair": 3, "hair_col": 2, "beard": 2, "top": 4, "top_col": 0, "bottom": 2, "bot_col": 4, "acc": 3, "build": 0.7, "shoes": 0},
		"sched": [[0, "tea", "off"], [5.4, "tea", "in"], [21.6, "tea", "off"]], "friends": ["basanna", "lakshmamma"]},
	"meena": {"role": "Runs the S.T.D. booth. Hears the whole city's secrets.", "job": "booth", "sex": 1, "home": "meena_home",
		"look": {"skin": 2, "hair": 7, "top": 9, "top_col": 11, "bottom": 5, "bot_col": 0, "acc": 5, "build": 0.3, "height": 0.45, "face": 5},
		"sched": [[0, "meena_home", "off"], [8.8, "std", "in"], [13.0, "darshini", "at"], [13.7, "std", "in"], [20.5, "meena_home", "off"]], "friends": ["shalini"]},
	"basanna": {"role": "Driver, Route 27E. Thirty-one years, zero accidents, one ulcer.", "job": "driver", "sex": 0, "home": "home",
		"look": {"skin": 3, "hair": 3, "hair_col": 2, "beard": 2, "top": 7, "top_col": 1, "bottom": 0, "bot_col": 1, "build": 0.75, "glasses": 1, "acc": 0, "shoes": 0},
		"sched": [[0, "home", "off"], [5.6, "majestic", "at"], [13.0, "tea", "sit"], [14.0, "majestic", "at"], [21.0, "bar", "at"], [22.6, "home", "off"]], "friends": ["nanjappa"]},
	"kitty": {"role": "Your younger brother. B.Com (discontinued).", "job": "idle", "sex": 0, "home": "home",
		"look": {"skin": 2, "hair": 4, "beard": 1, "top": 4, "top_col": 4, "bottom": 1, "build": 0.2, "height": 0.6, "acc": 0, "shoes": 2, "watch": 0},
		"sched": [[0, "home", "off"], [10.0, "tea", "sit"], [12.5, "home", "at"], [16.0, "darshini", "at"], [17.0, "home", "at"], [19.0, "tea", "sit"], [22.0, "home", "off"]], "friends": ["immu", "seena"]},
	"immu": {"role": "Auto driver. Your friend since Fourth Standard.", "job": "auto", "sex": 0, "home": "home",
		"look": {"skin": 3, "hair": 2, "beard": 5, "top": 7, "top_col": 1, "bottom": 0, "bot_col": 1, "build": 0.5, "acc": 0, "shoes": 0},
		"sched": [[0, "home", "off"], [7.0, "police", "at"], [13.0, "darshini", "at"], [14.0, "railway", "at"], [19.0, "tea", "sit"], [22.0, "home", "off"]], "friends": ["kitty", "seena"]},
	"seena": {"role": "Xerox shop boy. Dreams of Dubai.", "job": "clerk", "sex": 0, "home": "home",
		"look": {"skin": 4, "hair": 1, "beard": 0, "top": 3, "top_col": 2, "bottom": 0, "bot_col": 8, "build": 0.15, "acc": 0},
		"sched": [[0, "home", "off"], [9.0, "tailor", "at"], [19.0, "tea", "sit"], [22.0, "home", "off"]], "friends": ["kitty", "immu"]},
	"lokesh": {"role": "Sub-Inspector, Upparpet. His salary is a rumour.", "job": "police", "sex": 0, "home": "police",
		"look": {"skin": 2, "hair": 0, "beard": 3, "top": 1, "top_col": 1, "bottom": 0, "bot_col": 1, "build": 0.85, "glasses": 2, "acc": 2, "shoes": 1, "watch": 2},
		"sched": [[0, "police", "in"], [13.0, "darshini", "at"], [14.0, "police", "in"], [21.0, "bar", "at"], [23.0, "police", "in"]], "friends": ["soda"]},
	"shivaramu": {"role": "Inspector. Tired, honest, three years from pension.", "job": "police", "sex": 0, "home": "police",
		"look": {"skin": 3, "hair": 3, "hair_col": 2, "beard": 2, "top": 1, "top_col": 1, "bottom": 0, "bot_col": 1, "build": 0.6, "acc": 2, "shoes": 1},
		"sched": [[0, "police", "off"], [10.0, "police", "at"], [18.0, "police", "off"]], "friends": []},
	"tiger": {"role": "Flower merchant. Also other things.", "job": "don", "sex": 0, "home": "godown",
		"look": {"skin": 4, "hair": 2, "hair_col": 2, "beard": 3, "top": 5, "top_col": 0, "bottom": 3, "bot_col": 0, "build": 0.95, "acc": 1, "watch": 2, "height": 0.7, "face": 2},
		"sched": [[0, "godown", "off"], [5.0, "godown", "at"], [23.0, "godown", "off"]], "friends": ["oilkumar", "channanna"]},
	"oilkumar": {"role": "Thimmaiah's right hand. Named for what he once sold.", "job": "goon", "sex": 0, "home": "godown",
		"look": {"skin": 5, "hair": 5, "beard": 5, "top": 2, "top_col": 4, "bottom": 2, "bot_col": 3, "build": 0.9, "acc": 1, "height": 0.8},
		"sched": [[0, "godown", "at"], [20.0, "bar", "at"], [23.5, "godown", "at"]], "friends": ["tiger"]},
	"soda": {"role": "Video parlours, real estate, and a smile.", "job": "don", "sex": 0, "home": "parlour",
		"look": {"skin": 1, "hair": 1, "beard": 6, "top": 6, "top_col": 0, "bottom": 0, "bot_col": 0, "build": 0.45, "glasses": 2, "acc": 1, "watch": 2, "shoes": 1, "face": 4},
		"sched": [[0, "parlour", "off"], [11.0, "parlour", "at"], [20.0, "pub", "at"], [23.9, "parlour", "off"]], "friends": ["lokesh", "pinto"]},
	"pinto": {"role": "Anthony's collector. Polite until he is not.", "job": "goon", "sex": 0, "home": "parlour",
		"look": {"skin": 2, "hair": 0, "beard": 4, "top": 4, "top_col": 8, "bottom": 1, "build": 0.8, "acc": 1, "shoes": 2},
		"sched": [[0, "parlour", "at"]], "friends": ["soda"]},
	"channanna": {"role": "M.L.A., Janata Pragathi Paksha. Lantern symbol.", "job": "neta", "sex": 0, "home": "jpp",
		"look": {"skin": 3, "hair": 3, "hair_col": 3, "beard": 2, "top": 5, "top_col": 0, "bottom": 3, "bot_col": 0, "build": 1.0, "acc": 3, "watch": 2, "shoes": 4},
		"sched": [[0, "jpp", "off"], [9.5, "jpp", "at"], [17.0, "majestic", "at"], [19.0, "jpp", "at"], [21.0, "jpp", "off"]], "friends": ["tiger", "shetty"]},
	"vasantha": {"role": "Corporator, K.N.V. Plough symbol. Means it, mostly.", "job": "neta", "sex": 1, "home": "knv",
		"look": {"skin": 2, "hair": 8, "hair_col": 1, "top": 8, "top_col": 0, "bottom": 4, "bot_col": 5, "build": 0.5, "glasses": 1, "acc": 0, "face": 3},
		"sched": [[0, "knv", "off"], [9.0, "knv", "at"], [20.0, "knv", "off"]], "friends": ["shalini"]},
	"shetty": {"role": "Steel, castings, and half the land in Peenya.", "job": "boss", "sex": 0, "home": "shetty",
		"look": {"skin": 1, "hair": 1, "hair_col": 2, "beard": 0, "top": 6, "top_col": 12, "bottom": 0, "bot_col": 12, "build": 0.8, "glasses": 1, "watch": 2, "shoes": 1},
		"sched": [[0, "shetty", "off"], [10.0, "shetty", "at"], [19.0, "shetty", "off"]], "friends": ["channanna"]},
	"shalini": {"role": "Crime reporter, Sanje Vaani. Asks the second question.", "job": "press", "sex": 1, "home": "paper",
		"look": {"skin": 1, "hair": 8, "top": 9, "top_col": 2, "bottom": 5, "bot_col": 0, "build": 0.3, "glasses": 3, "acc": 0, "height": 0.55, "face": 4},
		"sched": [[0, "paper", "off"], [10.0, "paper", "at"], [13.0, "darshini", "at"], [14.0, "police", "at"], [17.0, "paper", "at"], [21.0, "paper", "off"]], "friends": ["meena", "vasantha"]},
	"lakshmamma": {"role": "Your landlady. The rent is due. It is always due.", "job": "landlady", "sex": 1, "home": "home",
		"look": {"skin": 3, "hair": 8, "hair_col": 2, "top": 8, "top_col": 4, "bottom": 4, "bot_col": 6, "build": 0.9, "acc": 0, "height": 0.3},
		"sched": [[0, "home", "off"], [6.0, "home", "at"], [10.0, "tea", "at"], [11.0, "home", "at"], [20.0, "home", "off"]], "friends": ["nanjappa"]},
	"rafiq": {"role": "Tailor. Measures you with one look.", "job": "tailor", "sex": 0, "home": "tailor",
		"look": {"skin": 2, "hair": 3, "hair_col": 2, "beard": 5, "top": 5, "top_col": 0, "bottom": 0, "bot_col": 12, "glasses": 3, "acc": 2, "build": 0.4},
		"sched": [[0, "tailor", "off"], [9.5, "tailor", "in"], [21.0, "tailor", "off"]], "friends": []},
	"balaji": {"role": "Second-hand vehicles. First-hand lies.", "job": "dealer", "sex": 0, "home": "dealer",
		"look": {"skin": 3, "hair": 2, "beard": 2, "top": 2, "top_col": 6, "bottom": 0, "bot_col": 8, "build": 0.8, "acc": 1, "watch": 2, "shoes": 1},
		"sched": [[0, "dealer", "off"], [9.5, "dealer", "in"], [20.5, "dealer", "off"]], "friends": []},
	"bhatta": {"role": "Cashier, Hotel Dwaraka. Tokens first.", "job": "cashier", "sex": 0, "home": "darshini",
		"look": {"skin": 2, "hair": 6, "beard": 0, "top": 0, "top_col": 0, "bottom": 3, "bot_col": 0, "build": 0.7, "acc": 3},
		"sched": [[0, "darshini", "off"], [6.0, "darshini", "in"], [22.0, "darshini", "off"]], "friends": []},
	"mani": {"role": "Waiter, Kaveri Bar. Remembers every order and every debt.", "job": "waiter", "sex": 0, "home": "bar",
		"look": {"skin": 4, "hair": 1, "beard": 1, "top": 0, "top_col": 0, "bottom": 0, "bot_col": 8, "build": 0.3},
		"sched": [[0, "bar", "off"], [11.0, "bar", "in"], [23.5, "bar", "off"]], "friends": []},
}

const CHAT := {
	"nanjappa": ["By-two coffee? Or are you a full-cup man today?", "The corporator's boys came for 'festival collection'. Which festival, I asked. They said, yours.", "Tea is two rupees. Advice is free. Guess which one people take.",
		"Basanna says the new buses will have doors that close by themselves. Then what will conductors shout at?"],
	"meena": ["Local call one rupee. S.T.D. after ten o'clock is half rate.", "Somebody called for you again. They breathe, they hang up. Very romantic.", "People think the glass on this booth is soundproof. It is not.",
		"My father wants me to marry a bank clerk. I told him I already count other people's money all day."],
	"basanna": ["Thirty-one years on this route. The potholes have seniority over me.", "A bus is like a marriage, Raji. Don't brake suddenly and nobody gets hurt.", "Check the ticket roll before the inspector does.",
		"My ulcer says it will rain. My ulcer is never wrong."],
	"kitty": ["Anna, one small loan. Very small. You won't even feel it.", "I am this close to a business. I just need the business.", "Don't look at me like Appa used to."],
	"immu": ["Meter is one-and-a-half after ten, saar. For you, only one-and-a-quarter.", "Three policemen, one auto, no fare. That's called public service.", "You want to go somewhere? I know every lane God forgot."],
	"seena": ["Dubai, Raji anna. One visa and I'm gone. You people will see me only in photos.", "I xeroxed a politician's mark sheet today. He failed in everything except confidence."],
	"lokesh": ["Conductor. Stand properly when you talk to the department.", "This city runs on adjustments. I am the adjustment.", "Don't loiter near the station. Loitering is my job."],
	"shivaramu": ["If you have something to report, report it. If not, go home safely.", "Thirty years of service and I still believe in the F.I.R. Call me a fool."],
	"tiger": ["Flowers die in a day. That is why the business never stops.", "Sit. In my godown even enemies get coffee first."],
	"oilkumar": ["Anna doesn't like waiting. I like it even less.", "You have honest eyes. Bad for you."],
	"soda": ["Everybody rents, my friend. Videos, houses, people.", "Thimmaiah is the past. Nice past. But past."],
	"pinto": ["Boss is busy.", "You're the ticket man. I remember faces. Also addresses."],
	"channanna": ["The lantern lights every poor man's house! ...Which channel are you from? Oh. Then move.", "Young man, in politics there are no enemies. Only future friends and current expenses."],
	"vasantha": ["Do you know how many street lights work in this ward? I counted. Eleven.", "They call me stubborn. From them, I take it as a certificate."],
	"shetty": ["My time is costly. Be brief or be rich.", "Land does not lie, does not vote and does not strike. That is why I buy it."],
	"shalini": ["Off the record? Nothing is off the record. But I can spell your name wrong if you like.", "I do the crime page. It's the only page where nobody lies about their age."],
	"lakshmamma": ["Rent. And tell your brother a tap is for water, not for washing his whole future.", "First of the month means first of the month, not 'first week, Lakshmamma'."],
	"rafiq": ["Stand straight. Hm. Conductor's shoulders. Bag on the left since many years, no?", "Terry-cot or pure cotton? Don't say 'anything'. Nobody wears 'anything'."],
	"balaji": ["Single owner, doctor driven, only to temple and back.", "Finance? Finance is my middle name. Balaji Finance... no, wait."],
	"bhatta": ["Token first, then eat. Next!", "Extra sambar is not a right. It is a relationship."],
	"mani": ["Usual? ...You don't have a usual. I'll decide.", "That table in the corner, don't look. Thimmaiah's people."],
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
const ACT := {"nanjappa": "work", "bhatta": "work", "rafiq": "work", "mani": "work", "meena": "work", "balaji": "read", "lokesh": "read", "shalini": "listen", "lakshmamma": "sweep"}

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
