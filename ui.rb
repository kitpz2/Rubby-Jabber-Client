require 'brzus.rb'
#Interfejs uzytkownika
class UI
#Konstruktor klasy.
  def initialize
	@uzytkownik=Brzus.new  
	begin
		print "Podaj nazwe konta(jid@serwer[/zasob]): "
		@jid=gets.strip
		print "Podaj haslo: "
		@haslo=gets.strip
		p "Prosze czekac, trwa laczenie..."
		@uzytkownik.loguj(@jid.split('\n')[0],@haslo)
	rescue
		puts "Błąd przy logowaniu!"
		exit
	end
	odbierz
	@rozmowa=0
  end
#Zapisuje historie
#jid [String] - kontakt (kazdy kontakt ma swój plik)
#wiadomosc [String] - wiadomosc do zapisania
  def zapisz_historie(jid,wiadomosc)
	plik=File.new("#{jid}","a+")
	plik.write(wiadomosc)
	plik.write("\n")
	plik.close
  end
#Obsluga zdarzen
  def odbierz
  Thread.new{
  		while(true)
  		sleep(0.5)
			wiadomosci=@uzytkownik.pobierz_wiadomosci
			if !wiadomosci.empty? then
				puts "\nOtrzymałeś nowe wiadomości: "
				wiadomosci.each do |wiadomosc|
					puts "#{wiadomosc.from}: #{wiadomosc.body}"
					zapisz_historie(wiadomosc.from.to_s.split('/')[0],"#{wiadomosc.from.to_s.split('/')[0]}: #{wiadomosc.body}")
				end
			end
			statusy=@uzytkownik.zmiany_statusow
			if !statusy.empty? then
				puts "\nZmiana statusu:"
				statusy.each do |s|			
					puts "#{s.from.to_s.split('/')[0]} zmienil/a status na #{podaj_status(s.show)}#{s.status ? "z opisem \"#{s.status}\"" : ""}"
				end
			end
			sub=@uzytkownik.nowe_subskrypcje
			if !sub.empty? then
				puts "\nProszą o subskrypcję:"
				sub.each do |s|
					puts "#{s.from}"
				end
			end
		end
	}
  end
#podanie statusu
#stat [String] - status
  def podaj_status(status)
	case status
	  when :away : return "Zaraz wracam"
	  when nil : return "Dostepny"
	  when :rozmowa : return "Chętny do rozmowy"
	  when :dnd : return "Nie przeszkadzac"
	  when :xa : return "Niewidoczny"
	  when :unavailable : return "Niedostepny"
	end
	"Błąd"
  end
#Wyswietla prosbe o podanie komendy
  def pytanie#:nodoc:
	puts "Zalogowałeś się, wpisz polecenie albo wpisz pomoc."
  end
#sprawdzenie czy jest rozmowa, jezeli nie to przekazuje polecenie do parsowania
  def cmd
	dzialaj=true
	polecenie=gets
	if @rozmowa==1 then
  		wyslijrozmowa(polecenie)
	else 
		if !(parsuj(polecenie)) then
		dzialaj=false
		end
	end
	return dzialaj
  end
#Parsuje polecenie
  def parsuj(slowo)
	polecenie=slowo.split
	if polecenie.length==0 then blad
	else
		case polecenie[0]
			when "dodaj": 
				      if polecenie.length==2 then dodaj(polecenie[1]) else blad end
			when "usun": 
				      if polecenie.length==2 then usun(polecenie[1]) else blad end
			when "usun_bez_s": 
				      if polecenie.length==2 then usun_bez_s(polecenie[1]) else	blad end
			when "usun_s": 
				      if polecenie.length==2 then usun_s(polecenie[1]) else	blad end
			when "lista": 
				      lista
			when "historia": 
					  if polecenie.length==2 then historia(polecenie[1]) else blad end
			when "rozmowa":  
				      if polecenie.length==2 then @rozmowa=1; rozmowa(polecenie[1]) else	blad end
			when "wiadomosc": 
					  if polecenie.length>2 then wiadomosc(polecenie) else blad end
			when "koniec": 
				       return false
			when "status": 
				       if polecenie.length<2&&polecenie.length>3 then blad
				       else
				       	status(polecenie[1],polecenie[2])
				       end	
			when "akceptuj": 
					   if polecenie.length==2 then akceptuj(polecenie[1]) else blad end			   
			when "odrzuc": 
				  	 	if polecenie.length==2 then odrzuc(polecenie[1]) else blad end
			else
				pomoc
				return true
			end
		return true
	end
  end
#Zmienianie statusu i opisu
#status [String] - nowy status
#opis [String] - nowy opis
  def status(status,opis)
	case status
		when "dostepny": stat=nil
		when "zw":	 stat=:away
		when "chetny":  stat=:rozmowa
		when "np":	 stat=:dnd
		when "ukryty":	 stat=:xa
	else
		blad
		return
	end
	@uzytkownik.zmien_status(stat,opis)
  end
#Funkcja akceptujaca prosbe o subskrypcje
#nJID [String] - jid kontaktu
  def akceptuj(nJID)
	jid=JID::new(nJID)
	@uzytkownik.akceptuj_subskrypcje(jid)
  end
#Funkcja odrzucajaca prosbe o subskrypcje
#nJID [String] - jid kontaktu
  def odrzuc(nJID)
	jid=JID::new(nJID)
	@uzytkownik.odrzuc_subskrypcje(jid)
  end
#Rozpoczynanie rozmowy z userem
#nJID [String] - kontakt
  def rozmowa(nJID)
	jid=JID::new(nJID)
	@rozmowa_z=jid
  end
#Wysyłanie wiadomosci podczas rozmowy
#text [String] -wiadomosc do wyslania
  def wyslijrozmowa(text)
  	polecenie=text.split
    if polecenie[0]=="!koniec" then
	    @rozmowa=0
    else
		do_wyslania=String.new("")
		text.each{|txt|
			do_wyslania+=txt
			do_wyslania+=" "
		}
		@uzytkownik.wyslij_msg(@rozmowa_z,text,:rozmowa)
		zapisz_historie(@rozmowa_z.to_s,"#{@jid}:\n#{text}")
	end
  end
#Dodaje usera do listy
#nJID [String] - kontakt
  def dodaj(nJID)
	jid=JID::new(nJID)
	@uzytkownik.dodaj_do_kontaktow(jid)
  end
#Usuwa usera z listy z usuniecem z subskrypcji
  def usun(nJID)
	jid=JID::new(nJID)
	@uzytkownik.usun_z_listy_z_subskrypcja(jid)
  end
#Usuwa usera z listy z bez usuwania z subskrypcji
  def usun_s(nJID)
	jid=JID::new(nJID)
	@uzytkownik.usun_subskrypcje(jid)
  end
#Usuwa usera z listy z bez usuwania z subskrypcji
  def usun_bez_s(nJID)
	jid=JID::new(nJID)
	@uzytkownik.usun_z_listy_bez_subskrypcji(jid)
  end
#Wyswietla kontakty
  def lista
	puts "Lista kontaktow:"
	if @uzytkownik.lista_kontaktow.empty? then
		puts "PUSTA"
		return
	end
	@uzytkownik.lista_kontaktow.keys.each{|kontakt|
		puts kontakt
	}
  end
#Pokazuje poprzednie rozmowy z kontaktem
#nJID [String] - kontakt
  def historia(jid)
	plik=File::new("#{jid}","r")
	if plik.nil? then
		puts "Nie było rozmów z #{jid}"
		return
	end
	puts plik.read
  end
#Wysyla wiadomosc
#slowa: [Array] - slowa[0] - polecenie, slowa[1] - uzytkownik, slowa[2..] - wiadomosc
  def wiadomosc(slowa)
	jid=JID::new(slowa[1])
	i=0
	do_wyslania=String.new("")
	slowa.each{|txt|
		if i>1 then
			do_wyslania+=txt+" "
		end
		i+=1
	}
	@uzytkownik.wyslij_msg(jid,do_wyslania,:normal)
	zapisz_historie(jid.to_s,"#{@jid}:\n#{do_wyslania}")
  end
#Wyswietla pomoc
  def pomoc
	puts "Polecenie\t argumenty\t <opcjonalne argumenty>\t\t -\t opis:"
	puts "help/?/pomoc\t\t\t\t\t\t	 -\twyświetla pomoc"
	puts "wiadomosc\t [JID] ]tresc]\t\t\t\t	 -\twysyła wiadomość do [JID]"
	puts "rozmowa\t\t [JID]\t\t\t\t\t	 -\trozpoczyna rozmowę z [JID], aby ją zakończyć należy wpisać !koniec"
	puts "!koniec\t\t\t\t\t\t\t	 -\twychodzi z rozmowy (tylko podczas rozmowy)"
	puts "dodaj\t\t [JID]\t\t\t\t\t	 -\tdodaje [JID] do listy kontaktów (prosząc automatycznie o subskrypcję)"
	puts "usun\t\t [JID]\t\t\t\t\t	 -\tusuwa [JID] z listy znajomych (usuwa subskrypcję)"
	puts "usun_s\t\t [JID]\t\t\t\t\t	 -\tusuwa subskrypcje dla [JID] (bez usuwania z listy znajomych)"
	puts "usun_bez_s\t [JID]\t\t\t\t\t	 -\tusuwa [JID] z listy znajomych (bez usuwania subskrypcji)"
	puts "akceptuj\t [JID]\t\t\t\t\t	 -\takceptuje prośbę [JID] o subskrypcje"
	puts "odrzuc\t\t [JID]\t\t\t\t\t	 -\todmawia subskrypcji [JID]"
	puts "lista\t\t\t\t\t\t\t	 -\tpokazuje liste znajomych"
	puts "status\t\t [nowy_status]\t <nowy_opis>\t\t\t -\t ustawia status na podany wraz z opisem. \n\tLista dostepnych statusow: "
	puts "\t\tdostepny     - Dostępny"
	puts "\t\tchetny       - Chętny do rozmowy"
	puts "\t\tnp           - Nie przeszadzac"
	puts "\t\tzw           - Zaraz wracam"
	puts "\t\tniewidoczny - Niewidoczny"
	puts "koniec\t\t\t\t\t\t\t	 -\t wychodzi z programu\n\n"

  end
#informacja o błędnym poleceniu
  def blad
	puts "Nie ma takiego polecenia, wpisz pomoc aby poznać polecenia"
  end
end
