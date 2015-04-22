function [ y,res ] = encode(x,cons)
% Compression using 1´s complement
% Sends 2 reference values. NOT resetting bit length and sequences of small
% changes

% pos max 16 bit '0111111111111111' +32767
% ned max 16 bit '1000000000000000' -32768

val = 5;

sign = '111111111111111111111111111111110';
s = 16;
ref = x(1);
res = [sign dec2bin(s-1,4)];    % Send 33 bit sign and 4 bit size
res = [res dec2bin(ref, s)];    % Send 16 bit reference value
res = [res dec2bin(ref, s)];    % Send 16 bit reference value again


c = 0;
i = 2;
counter = 0;
ind = 2;     

while (i <= size(x,2))
    
    counter = counter + 1;
    if counter >= 1000
        counter = 0;
        
        % Send old reference
        res = [res sign];                   % Add sign 33 bit sign
        res = [res dec2bin(s-1,4)];         % Send 4 bit current bit size
        %disp(dec2bin(s-1,4));
        res = [res dec2bin(ref,16)];        % Send reference 16 bit
        ind = ind + 1;
        
        % Send a new reference
        ref = x(i);
        res = [res dec2bin(ref,16)];        % Send reference 16 bit
        ind = ind + 1;
        
    else
        d = int32(x(i)) - int32(ref); 
        
        % Diff to large (positive)
        if (d >= 2^(s-1)-1) 
            res = [ res dec2bin(2^(s-1)-1,s)];  % Send pos max
            x(i-1) = x(i-1) + (2^(s-1)-1);      % Add max to x(i-1)
            s = s + 1; 
            i = i - 1; 
            c = 0; 

        % Diff to large (negative)
        elseif (d <= -(2^(s-1)-1))     
            res = [ res dec2bin(2^(s-1),s)];    % Send min max
            x(i-1) = x(i-1) - (2^(s-1));        % Subtract min from x(i-1)
            s = s + 1;
            i = i - 1;
            c = 0; 
        
        % Diff ok to send as is
        else 
            if ( d < 0 ) % Send a negative number      
                neg = dec2bin(2^(s)+d-1, s);      % Produces 1's complement neg number s bit
                res = [res neg];                % Send number
            else
                res = [ res dec2bin(d,s)];      % Send positive number s bit
            end; 
            
            % Check for small difference 
            if (d <= (2^(s-2)-1)) & ( d>= (-2^(s-2)))          
                c = c + 1;
            else
                c = 0; 
            end; 
            
            % check for series of small diff
            if (c >= cons)
                c = 0;       % reset counter
                s = s - 1;   % reduce bit-length
            end
        end;
    end
    
    i = i + 1;
end;

fprintf(1,'Number of references sendt : %i\n', ind);


% rewrap the string of 1s and 0s into an array of uint16
rs = size(res, 2);
ys = floor(rs/16);

for i = 0 : (ys - 1)
    y(i+1) = uint16(bin2dec(res((i*16+1) : (i+1) * 16)));
end; 

rest_bits = rs- (ys * 16);

if (rest_bits) > 0 % fill empty space in the last uint16 with zeros: can lead to one or a few extra copies of the last encoded number when decoding!
    y(ys+1) = uint16(bin2dec([res(((ys)*16+1) : rs) dec2bin(0,16-rest_bits)]));
end; % if