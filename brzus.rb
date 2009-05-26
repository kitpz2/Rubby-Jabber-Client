#Obsługa protokołu jabbera przy użyciu biblioteki xmpp4r
require 'xmpp4r'
require 'xmpp4r/roster'
require 'xmpp4r/roster/iq/roster'
require 'kontakt.rb'
include Jabber

#Główna klasa obsługująca klienta
class Brzus
#Inicjalizacja
  def initialize args={}
	@lista_msg=0
  end
#Logowanie
#adres [String] adres konta (jid@serwer[/zasob])
#haslo [String] haslo do konta
  def loguj(adres,haslo)
	jid=JID::new(adres)
	@uzytkownik=Client::new(jid)
	@uzytkownik.connect
	@uzytkownik.auth(haslo)
	@uzytkownik.send(Presence.new.set_type(:available))
	@kolejka_wiadomosci_do_wyslania=Queue.new
	inicjalizacje
	sleep(1)
	Thread.new{
		while(true)
			next if @kolejka_wiadomosci_do_wyslania.length<1
			wiadomosci=[@kolejka_wiadomosci_do_wyslania.pop]
			wiadomosci.each{ |wiadomosc|
				if jest_subskrypcja?(JID::new(wiadomosc[:do]))
					wyslij_msg(wiadomosc[:do],wiadomosc[:wiadomosc],wiadomosc[:jak])
				else
					@kolejka_wiadomosci_do_wyslania << wiadomosc
				end
			}
		end
	}
  end
#Dodaje nowy kontakt do kontaktow
#jid [Jabber::JID] - jid nowego kontaktu
  def dodaj_do_kontaktow(*jid)
	kontakty(*jid) do |kontakt|
		next if jest_subskrypcja?(kontakt)
		kontakt.prosba_o_subskrypcje
	end
  end
#Zwraca listę kontaktów
#zwraca: Hash{|Jabber::JID,Jabber::RosterItem|}
  def lista_kontaktow
	roster.items
  end
#Odebrane wiadomości
#zwraca: Jabber::Message
  def pobierz_wiadomosci
	wiadomosci=[]
	while(!@kolejka_wiadomosci.empty?)
		wiadomosc=@kolejka_wiadomosci.pop(true) rescue nil
		break if wiadomosc.nil?
		wiadomosci << wiadomosc
		yield wiadomosc if block_given?
	end
	wiadomosci
  end
#Zmiana statusu usera
#status [String] nowy status
#opis [String] opis statusu
#
#Mozliwe statusy do ustawienia
# nil  		- Dostepny
# :away 	- Zaraz wracam
# :chat 	- Chętny do rozmowy
# :dnd 		- Nie przeszkadzać
# :xa 		- Niewidoczny
# :unavailable 	- Niedostepny
  def zmien_status(status,opis)
	@status=status
	@opis=opis
	status_nowy=Presence.new(@status,@opis)
	wyslij(status_nowy)
  end
#Pobiera zmiany statusów znajomych
  def zmiany_statusow
	statusy=[]
	while(!@kolejka_statusow.empty?)
		status=@kolejka_statusow.pop(true) rescue nil
		break if status.nil?
		statusy << status
		yield status if block_given?
	end
	statusy
  end
#Akceptuje subskrypcje
#jid [Jabber::JID] - uzytkownik do zaakceptowania
  def akceptuj_subskrypcje(jid)
	roster.accept_subscription(jid)
  end
#Odrzuca subskrypcje
#jid [Jabber::JID] - uzytkownik do odrzucenia
  def odrzuc_subskrypcje(jid)
	roster.decline_subscription(jid)
  end
#Zwraca nowe subskrypcje
  def nowe_subskrypcje
	subskrypcje=[]
	while(!@prosba_subskrypcja.empty?)
		sub=@prosba_subskrypcja.pop(true) rescue nil
		break if sub.nil?
		subskrypcje << sub
		yield sub if block_given?
	end
	subskrypcje
  end
#wysylanie wiadomości do podanego jidu
#jid [Jabber::JID] do kogo wysyłamy
#wiadomosc [String] co wysyłamy
#jak [String] czy czat czy pojedyncza wiadomość
  def wyslij_msg(jid,wiadomosc,jak=:chat)
	kontakty(jid) do |znajomy|
		unless jest_subskrypcja? znajomy
			dodaj_do_kontaktow(znajomy.jid)
			return dodajDoWyslania_poAkcpetacji(znajomy.jid,wiadomosc,jak)
		end
		msg=Message.new(znajomy.jid)
		msg.type=jak
		msg.body=wiadomosc
		wyslij(msg)
	end
  end
#Wysyla polecenie do serwera
#W wypadku nie powodzenia prubuje 3 razy
  def wyslij(tresc)
	proba=0
	begin
		proba+=1
		@uzytkownik.send(tresc)
	rescue
		retry unless proba>3
	end
  end
#Usuwa kontakt ze znajomych usuwając automatycznie subskrypcje
#jid [Jabber::JID] - kontakt do usuniecia
  def usun_z_listy_z_subskrypcja(*jid)
	kontakty(*jid) do |lp|
		lp.usun_subskrypcje
		req=Iq.new_rosterset
		req.query.add(Roster::RosterItem.new(lp.jid,nil,:remove))
		wyslij(req)
	end
  end
#Usuwa subskrypcje kontaktu
#jid [Jabber::JID] - kontakt do usuniecia
  def usun_subskrypcje(*jid)
	kontakty(*jid) do |lp|
		lp.usun_subskrypcje
	end
  end
#Usuwa kontakt ze znajomych bez usuwania subskrypcji
#jid [Jabber::JID] - kontakt do usuniecia
  def usun_z_listy_bez_subskrypcji(*jid)
	kontakty(*jid) do |lp|
		req=Iq.new_rosterset
		req.query.add(Roster::RosterItem.new(lp.jid,nil,:remove))
		wyslij(req)
	end
  end
#Zwraca roster, w lub tworzy nowy jak nie a aktualnego
#jak zwracany [Jabber::Roster::Helper]
  def roster
	return @roster if @roster
	self.roster=Roster::Helper.new(@uzytkownik)
  end
  private
#Zwraca kontakt z listy kontaktów, lub dodaje nowy gdy go brak wysyłając prośbę o subskrypcję
  def kontakty(*kontakt)
	@kontakty||={}
	temp=[]
	kontakt.each do |temp_kontakt|
	   jid=temp_kontakt.to_s
	   unless @kontakty[jid]
		@kontakty[jid]=temp_kontakt.respond_to?(:prosba_o_subskrypcje) ? temp_kontakt : Kontakt.new(self,temp_kontakt)
	   end
	   yield @kontakty[jid] if block_given?
	    temp << @kontakty[jid]
	end
	temp.size > 1 ? temp : temp.first
  end
#Dodaje wiadomosc do kolejki oczekujacej na subskrypcje
  def dodajDoWyslania_poAkcpetacji(jid,wiadomosc,jak)
	msg={:do => jid, :wiadomosc => wiadomosc, :jak => jak}
	@kolejka_wiadomosci_do_wyslania << msg
  end
  def roster=(nowy)
	@roster=nowy
  end
#Inicjalizuje obsługę biblioteki
  def inicjalizacje
  	@kolejka_statusow=Queue.new
	@updt={}
	@mutex=Mutex.new
	roster.add_presence_callback do |item,stary,nowy|
		@kolejka_statusow << nowy
	end
  	@kolejka_wiadomosci=Queue.new
	@uzytkownik.add_message_callback do |wiadomosc|
		@kolejka_wiadomosci << wiadomosc unless wiadomosc.body.nil?
	end
	roster.add_query_callback do |iq|
	end
	@nowe_subskrypcje=Queue.new
	roster.add_subscription_callback do |rost,status|
		if status.type==:subscribed
			@nowe_subskrypcje<<[rost,status]
		end
	end
	@prosba_subskrypcja=Queue.new
	roster.add_subscription_request_callback do |rost,status|
		if status.type==:subscribe		
			@prosba_subskrypcja << status
		end
	end
  end
  def jest_subskrypcja?(jid)
	kontakty(jid) do |kontakt|
		return kontakt.jest_subskrypcja?
	end
  end

end
