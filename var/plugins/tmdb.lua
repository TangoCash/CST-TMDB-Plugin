--TMDB LUA Plugin
--From Ezak for coolstream.to
--READ LICENSE on https://github.com/Ezak91/CST-TMDB-Plugin.git
--2014

-- Aktuelle ChannelID für EPG Funktion ermitteln
function GetchannelID()
    local fname = "../tmp/tmdb_channelid.txt"
    os.execute("wget -q -O " .. fname .. " http://127.0.0.1/control/zapto" )
	local fp = io.open(fname, "r")
	if fp == nil then
		print("Error opening file '" .. fname .. "'.")
	end
	channelID = fp:read()
    fp:close()
end

--EPG zur aktuellen ChannelID ermitteln, parsen und pro Eintrag ein Menüitem erstellen
function GetEPG()
	local fname = "../tmp/tmdb_epg.txt"
    os.execute("wget -q -O " .. fname .. " 'http://127.0.0.1/control/epg?xml=true&channelid=" .. channelID .. "'" )
	local fp = io.open(fname, "r")
	if fp == nil then
		print("Error opening file '" .. fname .. "'.")
		os.exit(1)
	else
		local s = fp:read("*a")
		fp:close()
		titlenumber = 1
		for title in string.gmatch(s, "<!%[CDATA%[(.-)%]%]>") do
			if titlenumber == 1 then
			channelname = title
			m = menu.new{name=channelname}
			titlenumber = titlenumber + 1
			else
			--Funktion zum hinzufügen des Menüitems
			AddMenueitem(title)
			end
		end
		ShowMenue()
    end
end

--Funktion zum hinzufügen der EPG-Daten des aktuellen Channels
function AddMenueitem(_title)
	m:addItem{type="string", action="GenLink", id=_title,name=_title}
end

--EPG-Menue anzeigen
function ShowMenue()
	m:exec()
end

--Link zur Suche des Titels erstellen
function GenLink(_search)
lastSearch = _search
_search = _search:gsub("%s","%%20")
link = "http://api.themoviedb.org/3/search/" .. option .. "?api_key=311e70fd5d86a21b7ec0756a6067ac4d&language=de&query=" .. _search
Getquellcode( link)
end

--Quellcode einer Seite herunterladen zum Beispiel neue Kinofilme, oder Informationen zu einem gesuchten Film
function Getquellcode( _link)	
	local fname = "../tmp/tmdb_movies.txt"
	os.execute("wget -q -O " .. fname .. " '" .. _link  .. "'")
	ParseMovies()
end

--Parsen der heruntergeladenen Movieinfos
function ParseMovies()
    results = 0
	movies = {}
	local fname = "../tmp/tmdb_movies.txt"
	local fp = io.open(fname, "r")
	if fp == nil then
		print("Error opening file '" .. fname .. "'.")
		os.exit(1)
	else
		local s = fp:read("*a")
		fp:close()
		
		i = 1
		
		results = s:match("total_results\":(%d)%}")

		if results == '0' then
		  if option == 'movie' then
		    option = 'tv';
			GenLink(lastSearch);
		  else
			local h = hintbox.new{ title="Info", text="Leider keine Infos gefunden", icon="info"};
			h:exec();
			option = 'movie';
		  end
		else
		
			s = s:match("%[(.*)%]")

			for movie in string.gmatch(s, "%{(.-)%}") do
			movies[i] = 
			{
					id =  movie:match("id\":(.-),")
			}
			i = i + 1
			end
			movienumber = 1
			if option == 'movie' then
				GetMovieDetails();
			else
				GetTVDetails();
			end
		end	
	end	
end

--Details zur ersten gefundenen MovieID parsen
function GetMovieDetails()
    movieinfos = {}
	movieinfos.titel = ""
	movieinfos.originaltitel =  ""
	movieinfos.releasedate =  ""
	movieinfos.adult =  ""
	movieinfos.cover =  ""
	movieinfos.overview = ""
	movieinfos.vote = ""
	movieinfos.votecount =  ""
	movieinfos.runtime =  ""
	movieinfos.genres = " "
	
	local fname = "../tmp/tmdb_moviedetails.txt"
	os.execute("wget -q -O " .. fname .. " '" .. "http://api.themoviedb.org/3/movie/" .. movies[movienumber].id .. "?api_key=311e70fd5d86a21b7ec0756a6067ac4d&language=de" .. "'")
	
	local fp = io.open(fname, "r")
	if fp == nil then
		print("Error opening file '" .. fname .. "'.")
		os.exit(1)
	else
		local s = fp:read("*a")
		fp:close()
		
		movieinfos.titel = s:match("\"title\":\"(.-)\",")
		movieinfos.originaltitel =  s:match("original_title\":\"(.-)\",")
		movieinfos.releasedate =  s:match("release_date\":\"(.-)\",")
		movieinfos.adult =  s:match("adult\":(.-),")
		movieinfos.cover =  s:match("poster_path\":\"(.-)\",")
		movieinfos.overview =  s:match("overview\":\"(.-)\",")
		movieinfos.vote =  s:match("vote_average\":(.-),")
		movieinfos.votecount =  s:match("vote_count\":(.-)%}")
		movieinfos.runtime =  s:match("runtime\":(.-),")
		
		--genres parsen
		genrestmp = s:match("genres\":%[(.-)%}%]")
		for genre in string.gmatch(genrestmp, "name\":\"(.-)\"") do
			movieinfos.genres = movieinfos.genres .. " " .. genre
		end
	
		inhalt = "Titel: " .. movieinfos.titel  .. "\n" .. "Original Titel: " .. movieinfos.originaltitel .. "\n" .. "Dauer: " .. movieinfos.runtime .. " min" .. "\n" .. "Releasedate: " .. movieinfos.releasedate ..  "\n" .. "Genres: " .. movieinfos.genres .. "\n" .. "Adult: " .. movieinfos.adult .. "\n" .. "Bewertung: " .. movieinfos.vote  .. " / 10 (" .. movieinfos.votecount .. " Stimmen)" .. "\n" .. "\n" .. "TMDB Plugin by Ezak for www.coolstream.to";
		getPicture()
		ShowInfo()
	end	
end

--Details zur ersten gefundenen SerienID parsen
function GetTVDetails()
    movieinfos = {}
	movieinfos.titel = ""
	movieinfos.originaltitel =  ""
	movieinfos.releasedate =  ""
	movieinfos.cover =  ""
	movieinfos.overview = ""
	movieinfos.vote = ""
	movieinfos.votecount =  ""
	movieinfos.episodes =  ""
	movieinfos.seasons = ""
	movieinfos.genres = " "

	local fname = "../tmp/tmdb_moviedetails.txt"
	os.execute("wget -q -O " .. fname .. " '" .. "http://api.themoviedb.org/3/tv/" .. movies[movienumber].id .. "?api_key=311e70fd5d86a21b7ec0756a6067ac4d&language=de" .. "'")
	
	local fp = io.open(fname, "r")
	if fp == nil then
		print("Error opening file '" .. fname .. "'.")
		os.exit(1)
	else
		local s = fp:read("*a")
		fp:close()
		movieinfos.titel = s:match("\",\"name\":\"(.-)\",")
		movieinfos.originaltitel =  s:match("original_name\":\"(.-)\",")
		movieinfos.releasedate =  s:match("first_air_date\":\"(.-)\",")
		movieinfos.cover =  s:match("poster_path\":\"(.-)\",")
		movieinfos.overview =  s:match("overview\":\"(.-)\",")
		movieinfos.vote =  s:match("vote_average\":(.-),")
		movieinfos.votecount =  s:match("vote_count\":(.-)%}")
		movieinfos.seasons =  s:match("number_of_seasons\":(.-),")
		movieinfos.episodes = s:match("number_of_episodes\":(.-),")
				
		--genres parsen
		genrestmp = s:match("genres\":%[(.-)%}%]")
		for genre in string.gmatch(genrestmp, "name\":\"(.-)\"") do
			movieinfos.genres = movieinfos.genres .. " " .. genre
		end
	
		inhalt = "Titel: " .. movieinfos.titel  .. "\n" .. "Original Titel: " .. movieinfos.originaltitel .. "\n" .. "Erstausstrahlung: " .. movieinfos.releasedate .. "\n" .. "Staffeln: " .. movieinfos.seasons ..  "\n" .. "Episoden: " .. movieinfos.episodes .. "\n" .. "Genres: " .. movieinfos.genres ..  "\n" .. "Bewertung: " .. movieinfos.vote  .. " / 10 (" .. movieinfos.votecount .. " Stimmen)" .. "\n" .. "\n" .. "TMDB Plugin by Ezak for www.coolstream.to";
		getPicture()
		ShowInfo()
    end		
	
end

--Cover herunterladen
function getPicture()
if movieinfos.cover == nil  then
    local fname = "../tmp/tmdb_picture.jpg"
    os.execute("wget -q -U Mozilla -O " .. fname .. " 'http://d3a8mw37cqal2z.cloudfront.net/assets/f996aa2014d2ffd/images/no-poster-w185.jpg'" );
else
    local fname = "../tmp/tmdb_picture.jpg"
    os.execute("wget -q -O " .. fname .. " '" .. "http://image.tmdb.org/t/p/w500" .. movieinfos.cover .. "'" )
end
end

--Infos im Fenster erzeugen
function ShowInfo()
oldOption = option;
n = neutrino();

local spacer = 8;
local x  = 150;
local y  = 70;
local dx = 1000;
local dy = 600;

if option == 'movie' then
	btnGreenText = 'Serien';
else
	btnGreenText = 'Filme';
end
utitel = "TMDB Info: " .. movieinfos.titel
 
w = cwindow.new{x=x, y=y, dx=dx, dy=dy, title=utitel, btnRed="Bild speichern", 
			btnGreen=btnGreenText};
w:paint();

ct1 = ctext.new{x=x+220, y=y+50, dx=500, dy=260, text=inhalt,font_text=FONT['MENU']};
ct1:paint();

ct2 = ctext.new{x=160, y=y+330, dx=1000, dy=230, text=movieinfos.overview,mode = "ALIGN_SCROLL"};
ct2:paint();

n:DisplayImage("/tmp/tmdb_picture.jpg", 160, 130, 190, 260)

neutrinoExec()
CloseNeutrino()

if oldOption == option then
	option = 'movie';
else
	GenLink(lastSearch);
end

end

--Fenster anzeigen und auf Tasteneingaben reagieren
function neutrinoExec()
	repeat
		msg, data = n:GetInput(500)
		-- Taste Rot versteckt den Text
		if (msg == RC['red']) then
			--ct2:hide();
		-- Taste Grün zeigt den Text wieder an
		elseif (msg == RC['green']) then
			if option == 'tv' then
				option = 'movie';
			else
				option = 'tv';
			end
			msg = RC['home'];
		-- Mit den Tasten up/down bzw. page_up/page_down kann der Text gescrollt werden,
		-- falls erforderlich
		elseif (msg == RC['up'] or msg == RC['page_up']) then
			ct2:scroll{dir="up"};
		elseif (msg == RC['down'] or msg == RC['page_down']) then
			ct2:scroll{dir="down"};
		end
	-- Taste Exit oder Menü beendet das Fenster
	until msg == RC['home'] or msg == RC['setup'];
end

--Fenster schließen
function CloseNeutrino()
	ct1:hide();
	ct2:hide();
	w:hide();
end

--[[
MAIN
]]
option = 'movie';
GetchannelID();
GetEPG();
os.execute("rm /tmp/tmdb_*.*");	
n = nil
m = nil
collectgarbage();

