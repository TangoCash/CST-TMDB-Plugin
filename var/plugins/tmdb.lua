-- The MIT License (MIT)

-- Copyright (c) 2014 Marc Szymkowiak (Ezak)

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local json = require "json"
local posix = require "posix"

--Initialize global variables
function init()
	tmpPath 			= "/tmp/tmdb_plugin"
	os.execute("rm -rf " .. tmpPath)
	os.execute("sync")
	os.execute("mkdir -p " .. tmpPath)
	user_agent 			= "\"Mozilla/5.0 (Windows NT 6.1; WOW64; rv:31.0) Gecko/20100101 Firefox/31.0\""
	wget_cmd 			= "wget -q -U " .. user_agent .. " -O "
	mediaType = "movie";
	language = "";
	apiKey = "";
	mode_parameter = "false";
	search_string = "";
	n = neutrino();
end

-- Read configs
function readConfs()
	--msz
	language = "de";
	apiKey = "311e70fd5d86a21b7ec0756a6067ac4d";
end

-- Main Menu
function showMainMenu()
	mainMenu = menu.new{name="TMDB Plugin", icon=pluginIcon};
	mainMenu:addItem{type="forwarder", name="Aktueller Sender", action="getEPG", icon=1, directkey=RC["1"]};
	mainMenu:addItem{type="forwarder", name="Von Festplatte", action="loadMovies", icon=2, directkey=RC["2"]};
	mainMenu:addItem{type="forwarder", name="Suche", action="searchMovie", icon=3, directkey=RC["3"]};
	mainMenu:addItem{type="separatorline"};
	mainMenu:addItem{type="forwarder", name="Einstellungen", action="setOptions", id="-2", icon="blau", directkey=RC["blue"]};
	mainMenu:exec();
end

-- Search Menu for Movie
function searchMovie()
	hideMenu(mainMenu);
	searchMenu = menu.new{name="Film suchen", icon=pluginIcon};
	searchMenu:addItem{type="stringinput", action="setSearchString", value=search_string, sms=1, name="Filmtitel"};
	searchMenu:addItem{type="forwarder", name="Suchen", action="search", icon="blau", directkey=RC["blue"]};
	searchMenu:exec();
end

-- Set title to search
function setSearchString(_index, _value)
	search_string = string.gsub(_value," ","%%20");
end

-- Search Movie
function search()
	hideMenu(searchMenu);
	genLink(search_string);
end

--Link zur Suche des Titels erstellen
function genLink(_title)
	_title = _title:gsub("%s","%%20");
	local link = "http://api.themoviedb.org/3/search/" .. mediaType .. "?api_key=" .. apiKey .. "&language=" .. language .. "&query=" .. _title;
	getSearchResults(link);
end

-- Get Search Results
function getSearchResults(_link)
	local tmpFile = tmpPath .. "/tmdb_seachresults.txt";
	os.execute("rm -rf " .. tmpFile);
	os.execute(wget_cmd .. tmpFile .. " '" .. _link .. "'" );	
	local result = readFile(tmpFile);
   	local result_table = json:decode(result);
	local firstID = result_table.results[1].id;
	getInfos(firstID);
end

-- Get infos from Movie/Serie
function getInfos(_id)
	local tmpFile = tmpPath .. "/tmdb_movieinfos.txt";
	os.execute("rm -rf " .. tmpFile);
	os.execute(wget_cmd .. tmpFile .. " 'http://api.themoviedb.org/3/" .. mediaType .."/" .. _id .. "?api_key=" .. apiKey .. "&language=" .. language .. "'");
    local result = readFile(tmpFile);
   	local result_table = json:decode(result); 
   	if result_table.poster_path ~= nil then
   		getCover(result_table.poster_path);
   	end 
    showInfos(result_table);
end

-- Load Cover
function getCover(_picture)
	local tmpFile = tmpPath .. "/tmdb_cover.jpg";
	os.execute("rm -rf " .. tmpFile);
	os.execute(wget_cmd .. tmpFile .. " 'http://image.tmdb.org/t/p/w500" .. _picture .."'");
end

-- Show infos from Movie/Serie
function showInfos(_infos)

	local movieGenres = "";

	for index, genre in pairs(_infos.genres) do
		movieGenres = movieGenres .. genre.name .. " ";
	end

    movieInfos = "Titel: " .. _infos.title .. "\n" .. "Original Titel: " .. _infos.original_title .. "\n" .. "Dauer: " .. _infos.runtime;
    movieInfos = movieInfos .. " min" .. "\n" .. "Releasedate: " .. _infos.release_date .. "\n" .. "Genre: " .. movieGenres .. "\n";
    movieInfos = movieInfos .. "Voting: " .. _infos.vote_average .. " / 10  (" .. _infos.vote_count .. " Stimmen)";

    local windowTitle = "TMDB Info: " .. _infos.title;

	local spacer = 8;
	local x  = 150;
	local y  = 70;
	local dx = 1000;
	local dy = 600;
	 
	w = cwindow.new{x=x, y=y, dx=dx, dy=dy, title=windowTitle, btnRed="Bild speichern",btnGreen="Filminfos speichern"};
	w:paint();

	ct1 = ctext.new{x=x+220, y=y+50, dx=500, dy=260, text=movieInfos,font_text=FONT['MENU']};
	ct1:paint();

	ct2 = ctext.new{x=160, y=y+330, dx=1000, dy=230, text=_infos.overview,mode = "ALIGN_SCROLL"};
	ct2:paint();

	n:DisplayImage(tmpPath .. "/tmdb_cover.jpg", 160, 130, 190, 260);

	neutrinoExec()
end

-- Show infowindow and wait for input
function neutrinoExec()
	repeat
		msg, data = n:GetInput(500)
		if (msg == RC['green']) then
			--msg = RC['home'];
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

-- Read File
function readFile(_File)
	local fp, s
	fp = io.open(_File, "r")
	if fp == nil then 
		error("Error opening file '" .. _File .. "'.");
	end
		s = fp:read("*a");
		fp:close();
		return s;
end

-- Set mediaType to movie or serie
function setType(_type)
	mediaType = _type;
end

-- Hide Menu
function hideMenu(menu)
	if menu ~= nil then menu:hide() end
end

-- Debug Function 
function debug(_string)
	local ret = messagebox.exec{ title="Debug", text=_string, buttons={"cancel"} };
end	

--====================================================================================================================================
--[[
MAIN
]]

init();
readConfs();

if arg[3] ~= nil then
	mode_parameter = "true";
end

if mode_parameter == "true" then
	genLink(arg[3]);
else
	showMainMenu();
	--genLink("prakti.com")
end

os.execute("rm -rf " .. tmpPath);