 program chess;

 uses crt;

 const C1 = 1;
       C2 = 3;
       P  = 0;
       B  = 15;

 type peca = record
               tipo : string;
               cor : integer;
             end;
      reg = record
              case ocupado : boolean of
                true : (pecas : peca);
            end;
      tab = array[1..8,1..8] of reg;
 procedure h(cor : integer);
  begin
    textcolor(cor);
    highvideo;
  end;
 procedure cor(cor1,cor2 : integer);
  begin
    textcolor(cor1);
    textbackground(cor2);
  end;
 procedure peao(var tabul : tab; i,j,i1,cor : integer);
  begin
    if (i=i1) then begin
       tabul[i,j].pecas.tipo := 'Pe';
       tabul[i,j].pecas.cor := cor;
    end;
  end;
 procedure posicao(var tabul : tab; i,j,i1,j1,i2,j2 : integer; tipo : string; cor : integer);
  begin
    if ((i=i1)and(j=j1))or((i=i2)and(j=j2)) then begin
       tabul[i,j].pecas.tipo := tipo;
       tabul[i,j].pecas.cor := cor;
    end;
  end;
 procedure rainha_rei(var tabul : tab; i,j,i1,j1 : integer; tipo : string; cor : integer);
  begin
    if (i=i1)and(j=j1) then begin
        tabul[i,j].pecas.tipo := tipo;
        tabul[i,j].pecas.cor := cor;
    end;
  end;
 procedure start(var tabul : tab);
  var i,j : integer;
  begin
    for i := 1 to 8 do
       for j := 1 to 8 do begin
          if (i<=2) or (i>=7) then tabul[i,j].ocupado := true
             else tabul[i,j].ocupado := false;

          peao(tabul,i,j,2,P);
          peao(tabul,i,j,7,B);

          posicao(tabul,i,j,1,1,1,8,'To',P);
          posicao(tabul,i,j,8,1,8,8,'To',B);

          posicao(tabul,i,j,1,3,1,6,'Bi',P);
          posicao(tabul,i,j,8,3,8,6,'Bi',B);

          posicao(tabul,i,j,1,2,1,7,'Ca',P);
          posicao(tabul,i,j,8,2,8,7,'Ca',B);

          rainha_rei(tabul,i,j,1,4,'Ra',P);
          rainha_rei(tabul,i,j,8,4,'Ra',B);

          rainha_rei(tabul,i,j,1,5,'Re',P);
          rainha_rei(tabul,i,j,8,5,'Re',B);

       end;
    end;
 procedure msg(text:string);
  var x,y : integer;
  begin
    for y := 45 to 50 do gotoxy(1,y); clreol;
    for x := 1 to 79 do
      begin
        gotoxy(x,45); write(chr(205));
        gotoxy(x,50); write(chr(205));
      end;
    for y := 45 to 50 do
      begin
        gotoxy(1,y); write(chr(186));
        gotoxy(79,y); write(chr(186));
      end;
    gotoxy(1,45); write(chr(201));
    gotoxy(1,50); write(chr(200));
    gotoxy(79,45); write(chr(187));
    gotoxy(79,50); write(chr(188));
    gotoxy(3,45); write('[ MSG ]');
    gotoxy(3,47); write(text);
  end;
 procedure nmsg(n : integer);
  var str : string;
  begin
    case n of
      1 : str := 'Jogador Preto ganhou o jogo';
      2 : str := 'Jogador Branco ganhou o jogo';
    end;
    msg(str);
  end;
 procedure xy;
  var x,y : integer;
  begin
    for y := 2 to 7 do gotoxy(1,y); clreol;
    for x := 60 to 79 do
      begin
        gotoxy(x,2); write(chr(205));
        gotoxy(x,7); write(chr(205));
      end;
    for y := 2 to 7 do
      begin
        gotoxy(60,y); write(chr(186));
        gotoxy(79,y); write(chr(186));
      end;
    gotoxy(60,2); write(chr(201));
    gotoxy(60,7); write(chr(200));
    gotoxy(79,2); write(chr(187));
    gotoxy(79,7); write(chr(188));
    gotoxy(62,2); write('[ Pos ]');
    gotoxy(62,4); write('Letra:');
    gotoxy(62,5); write('Num:');
  end;
 procedure print(var tabul : tab; x,y : integer);
  var i,j : integer;
  begin
    msg('');
    xy;
    for i := 1 to 8 do
       for j := 1 to 8 do begin
          cor(B,P);
          gotoxy(x+4*j+1,y+1);write(j);   {================}
          gotoxy(x+1,y+3*i+1);            {  1 2 3 4 5 ... }
            case i of                     { A              }
              1 : write('A');             { B              }
              2 : write('B');             { C              }
              3 : write('C');             { D              }
              4 : write('D');             { E              }
              5 : write('E');             { F              }
              6 : write('F');             { .              }
              7 : write('G');             { .              }
              8 : write('H');             { .              }
            end;                          {================}

          if odd(i+j) then h(C1)
             else h(C2);
          gotoxy(x+4*j,y+3*i);write(chr(219),chr(219),chr(219),chr(219));
          gotoxy(x+4*j,y+3*i+1);write(chr(219));
          if tabul[i,j].ocupado = true then
             begin
               if tabul[i,j].pecas.cor = 0 then cor(B,P)
                  else cor(P,B);
               lowvideo;
               write(tabul[i,j].pecas.tipo);
             end
          else write(chr(219),chr(219));

          if odd(i+j) then h(C1)
             else h(C2);
          write(chr(219));

          gotoxy(x+4*j,y+3*i+2);write(chr(219),chr(219),chr(219),chr(219));
       end;
       normvideo;
  end;
  procedure busca(var tabul : tab);
   var i,j,pp,pb : integer;
   begin
     pp := 0;
     pb := 0;
     for i := 1 to 8 do
        for j := 1 to 8 do begin
           if tabul[i,j].ocupado = true then
              if tabul[i,j].pecas.cor = P then inc(pp)
                 else if tabul[i,j].pecas.cor = B then inc(pb);
        end;
     if pb = 0 then nmsg(1);
     if pp = 0 then nmsg(2);
   end;
  procedure lexy(var l,n : integer);
   var x : char;
   begin
      xy;
      repeat
        gotoxy(75,4);readln(x);
      until (x in['a'..'h','A'..'H']);
      {-$I}
      repeat
        gotoxy(75,5);readln(n);
      until (IOResult = 0) and ((n>=1) and (n<=8));
      {+$I}
      case x of
        'a','A' : l:=1;
        'b','B' : l:=2;
        'c','C' : l:=3;
        'd','D' : l:=4;
        'e','E' : l:=5;
        'f','F' : l:=6;
        'g','G' : l:=7;
        'h','H' : l:=8;
      end;
   end;
 procedure move(var tabul : tab; x1,y1,x2,y2 : integer);
   begin
     tabul[x2,y2].ocupado := true;
     tabul[x2,y2].pecas.tipo := tabul[x1,y1].pecas.tipo;
     tabul[x2,y2].pecas.cor := tabul[x1,y1].pecas.cor;
     tabul[x1,y1].ocupado := false;
   end;

  {==============Programa Principal==============}

  var tabul  : tab;
      n1,l1,n2,l2    : integer;
  begin
    clrscr;
    start(tabul);
    repeat
    print(tabul,22,10);
    lexy(l1,n1);
    lexy(l2,n2);
    move(tabul,l1,n1,l2,n2);
    until 1=2;
  end.
