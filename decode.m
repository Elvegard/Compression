function [y]=decode(res,cons, xx)
% Decodes expecting 2 reference values after each sign
% NOT resetting bit length or sequences of small changes.

sign = '111111111111111111111111111111110';  % '1111111111111111', 65535
y = 0;
len = size(res,2);

j = 1;                      % Index for storing numbers         
c = 0;              
ind = 0;                    % Number of references received
k = dec2bin(0, 33);         % 33 zeros
s = 16;                     % To get loop moving
i = uint32(1);              % Start at beginning


while (i + s - 1 ) <= len  
    
    % Find 32 1's in a row to indicate reference value
    if (i+32) <= len
        k = res(i:i+32);
    end

    if k == '111111111111111111111111111111110' % Indicator (33 bit)
        ind = ind + 1;                          % Count references found
        i = i + 33;                             % Jump to bit size index
        
        s = uint32(bin2dec(res(i:i+3))) + 1;    % Read bit size (4 bit)

        i = i + 4;                              % Jump to reference value index
        ref = uint32(bin2dec(res(i:(i+15))));   % Read reference value (16 bit)
        
        i = i + 16;                             % Jump 16 bits further in stream readout
        ref = uint32(bin2dec(res(i:(i+15))));   % Read reference value (16 bit)
        y(j) = ref; 
        ind = ind + 1;
   
        j = j + 1;                              % Prep for next number to be stored
        i = i + 16;                             % Jump 16 bits further in bit stream 

    else
        if ( uint16(bin2dec(res(i:i+s-1))) == (2^(s-1)-1) ) % Case positive max found
            i = i + s;      % Jump to next part of diff
            s = s + 1;      % Next number is represented with s+1 bits
            j = j - 1;
            c = 0;
            
        elseif ( res(i:i+s-1) == dec2bin((2^(s-1)), s) ) % Case negative max found
            i = i + s;      % Move index from indicator number
            s = s + 1;      % Next number is represented with s+1 bits
            j = j - 1;
            c = 0;
            
        else % Case size of value OK
            d = uint32(bin2dec(res(i:(i+s-1)))); % Read out diff value
            
            if res(i) == '1'        % Indicates a negative number
                y(j) = ref;         % Store number
                tmp = dec2bin(2^(s)-d-1, s);
                d = uint32(bin2dec(tmp));
                y(j) = y(j) - d;    % Subtract diff
                
                if d <= (2^(s-2))
                    c = c + 1;
                else
                    c = 0;
                end
    
            else
                y(j) = ref;         % Store number
                y(j) = y(j) + d;    % Add diff
                
                if d <= (2^(s-2)-1)
                    c = c + 1;
                else
                    c = 0;
                end
            end

            i = i + s;
        end
        
        % Live error checking. Stops processing if error is found
        if y(j) ~= xx(j)
            fprintf(1,'ERROR! %i: x=%i y=%i ref=%i s=%i d=%i c=%i\n', j, xx(j), y(j), ref , s, d, c);
        end

        % Adjust number of bits to be read
        if (c >= cons)
            c = 0;
            s = s - 1;
        end
        j = j + 1;  % Prep for storing next number
    end;
end;

y = uint16(y);

fprintf(1,'Number of references found : %i\n', ind);

