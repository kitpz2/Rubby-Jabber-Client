#!/usr/bin/ruby
require 'xmpp4r'
require 'xmpp4r/roster'
include Jabber

#Klasa będąca kontaktem
class Kontakt
#Konstruktor
  def initialize(uzytkownik,jid)
     @jid=jid.respond_to?(:resource)? jid : JID.new(jid)
     @uzytkownik=uzytkownik
  end
#Zwraca jid usera
  def jid(podst=true)
	podst ? @jid.strip : @jid
  end
#Usuwa subskrypcje usera
  def usun_subskrypcje
     usun=Presence.new.set_type(:unsubscribe)
     usun.to=jid
     @uzytkownik.wyslij(usun)
     @uzytkownik.wyslij(usun.set_type(:unsubscribed))
  end
#czy jest obustronna subskrypcja
  def jest_subskrypcja?
	[:to,:both].include?(subskrypcja)
  end
#Zwraca subskrypcje kontaktu z rostera
  def subskrypcja
     rost && rost.subscription
  end
#Zwraca kontakt z rostera
  def rost
	@uzytkownik.roster.items[@jid]
  end
#Wysyla prosbe o autoryzacje do usera
  def prosba_o_subskrypcje
     prosba=Presence.new.set_type(:subscribe)
     prosba.to=jid
     @uzytkownik.wyslij(prosba)
  end

end

