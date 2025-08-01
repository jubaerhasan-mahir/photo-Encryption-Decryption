classdef ImageEncryptionApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        GridLayout                     matlab.ui.container.GridLayout
        AdminPanel                     matlab.ui.container.Panel
        AdminLabel                     matlab.ui.control.Label
        UploadImageButton              matlab.ui.control.Button
        AdminImagePanel                matlab.ui.container.Panel
        AdminImageAxes                 matlab.ui.control.UIAxes
        AdminStatusLabel               matlab.ui.control.Label
        GenerateKeyButton              matlab.ui.control.Button
        KeyDisplayArea                 matlab.ui.control.TextArea
        CopyKeyButton                  matlab.ui.control.Button
        
        UserPanel                      matlab.ui.container.Panel
        UserLabel                      matlab.ui.control.Label
        EnterKeyButton                 matlab.ui.control.Button
        KeyInputArea                   matlab.ui.control.TextArea
        UserImagePanel                 matlab.ui.container.Panel
        UserImageAxes                  matlab.ui.control.UIAxes
        UserStatusLabel                matlab.ui.control.Label
        DownloadImageButton            matlab.ui.control.Button
        
        % Progress indicators
        AdminProgressBar               matlab.ui.control.Label
        UserProgressBar                matlab.ui.control.Label
    end

    properties (Access = private)
        OriginalImage                  % Original uploaded image
        GrayscaleImage                 % Grayscale version
        EncryptedImage                 % Encrypted image
        DecryptedImage                 % Decrypted image
        ReconstructedImage             % Final reconstructed image
        ChaosIndices                   % Chaos sequence for encryption/decryption
        DiffusionKey                   % Key for diffusion process
        GeneratedKey                   % The 256-digit key
        ImageDimensions                % [rows, cols]
        EncryptionTimer                % Timer for animations
        DecryptionTimer                % Timer for animations
        IsImageUploaded                % Flag to check if image is uploaded
    end

    methods (Access = private)

        function startupFcn(app)
            % Initialize the app
            app.IsImageUploaded = false;
            app.AdminStatusLabel.Text = 'Ready to upload image...';
            app.UserStatusLabel.Text = 'Waiting for admin to upload image...';
            app.GenerateKeyButton.Visible = false;
            app.KeyDisplayArea.Visible = false;
            app.CopyKeyButton.Visible = false;
            app.DownloadImageButton.Visible = false;
            app.AdminProgressBar.Visible = false;
            app.UserProgressBar.Visible = false;
        end

        function UploadImageButtonPushed(app, ~)
            % Upload and process image
            [filename, filepath] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tiff', 'Image Files'}, 'Select Image');
            
            if filename == 0
                return;
            end
            
            try
                % Read the image
                app.OriginalImage = imread(fullfile(filepath, filename));
                app.IsImageUploaded = true;
                
                % Start the encryption process with animation
                app.startEncryptionProcess();
                
            catch ME
                uialert(app.UIFigure, sprintf('Error loading image: %s', ME.message), 'Error');
            end
        end

        function startEncryptionProcess(app)
            % Disable upload button during process
            app.UploadImageButton.Enable = false;
            app.AdminProgressBar.Visible = true;
            app.AdminProgressBar.Text = 'Progress: 0%';
            
            % Keep window in focus
            figure(app.UIFigure);
            
            % Step 1: Display Original Image
            app.AdminStatusLabel.Text = 'Displaying original image...';
            imshow(app.OriginalImage, 'Parent', app.AdminImageAxes);
            app.AdminImageAxes.Title.String = 'Original Image';
            app.AdminProgressBar.Text = 'Progress: 25%';
            drawnow;
            pause(2); % Increased from 1 to 2 seconds (0.5x speed)
            
            % Step 2: Convert to Grayscale with Animation
            app.AdminStatusLabel.Text = 'Converting to grayscale...';
            app.animateGrayscaleConversion();
            app.AdminProgressBar.Text = 'Progress: 50%';
            
            % Step 3: Apply Confusion (Shuffling)
            app.AdminStatusLabel.Text = 'Applying confusion (shuffling)...';
            app.applyConfusion();
            app.AdminProgressBar.Text = 'Progress: 75%';
            
            % Step 4: Apply Diffusion (Encryption)
            app.AdminStatusLabel.Text = 'Applying diffusion (encryption)...';
            app.applyDiffusion();
            app.AdminProgressBar.Text = 'Progress: 100%';
            
            % Show Generate Key button
            app.AdminStatusLabel.Text = 'Encryption completed! Generate key to proceed.';
            app.GenerateKeyButton.Visible = true;
            app.UploadImageButton.Enable = true;
            
            % Ensure window stays in focus
            figure(app.UIFigure);
        end

        function animateGrayscaleConversion(app)
            % Animate the conversion from color to grayscale
            if size(app.OriginalImage, 3) == 3
                steps = 40; % Increased from 20 to 40 steps for more precise visualization
                for i = 1:steps
                    alpha = i / steps;
                    % Blend from color to grayscale
                    gray3channel = repmat(rgb2gray(app.OriginalImage), [1, 1, 3]);
                    blended = (1-alpha) * double(app.OriginalImage) + alpha * double(gray3channel);
                    imshow(uint8(blended), 'Parent', app.AdminImageAxes);
                    app.AdminImageAxes.Title.String = sprintf('Converting to Grayscale (%d%%)', round(alpha*100));
                    drawnow;
                    figure(app.UIFigure); % Keep focus
                    pause(0.1); % Increased from 0.05 to 0.1 seconds (0.5x speed)
                end
                app.GrayscaleImage = rgb2gray(app.OriginalImage);
            else
                app.GrayscaleImage = app.OriginalImage;
            end
            
            imshow(app.GrayscaleImage, 'Parent', app.AdminImageAxes);
            app.AdminImageAxes.Title.String = 'Grayscale Image';
            drawnow;
            pause(1); % Increased from 0.5 to 1 second (0.5x speed)
        end

        function applyConfusion(app)
            % Apply confusion with chaos map
            [row, col] = size(app.GrayscaleImage);
            app.ImageDimensions = [row, col];
            s = row * col;
            
            % Generate chaos sequence
            r = 3.62;
            x = zeros(1, s);
            x(1) = 0.7;
            
            for n = 1:s-1
                x(n+1) = r * x(n) * (1 - x(n));
            end
            
            [~, app.ChaosIndices] = sort(x);
            
            % Apply progressive shuffling with animation
            img_flat = app.GrayscaleImage(:);
            timg = img_flat;
            
            shuffle_steps = 200; % Increased from 50 to 200 steps for much more precise visualization
            pixels_per_step = ceil(s / shuffle_steps);
            
            for step = 1:shuffle_steps
                start_idx = (step-1) * pixels_per_step + 1;
                end_idx = min(step * pixels_per_step, s);
                
                % Apply shuffling
                for m = start_idx:end_idx
                    if m <= s
                        t1 = timg(m);
                        timg(m) = timg(app.ChaosIndices(m));
                        timg(app.ChaosIndices(m)) = t1;
                    end
                end
                
                % Update display more frequently for better visualization
                if mod(step, 10) == 0 || step == shuffle_steps % Changed from mod 5 to mod 10 for more frequent updates
                    img_confused = reshape(timg, [row, col]);
                    imshow(img_confused, 'Parent', app.AdminImageAxes);
                    app.AdminImageAxes.Title.String = sprintf('Confusion (%d%%)', round(100*step/shuffle_steps));
                    drawnow;
                    figure(app.UIFigure); % Keep focus
                    pause(0.2); % Increased from 0.1 to 0.2 seconds (0.5x speed)
                end
            end
            
            app.EncryptedImage = reshape(timg, [row, col]);
        end

        function applyDiffusion(app)
            % Generate diffusion key
            [row, col] = size(app.GrayscaleImage);
            s = row * col;
            
            p = 3.628;
            k = zeros(1, s);
            k(1) = 0.632;
            
            for n = 1:s-1
                k(n+1) = cos(p * acos(k(n)));
            end
            
            k = abs(round(k * 255));
            ktemp = de2bi(k);
            ktemp = circshift(ktemp, 1, 2);
            ktemp = bi2de(ktemp)';
            app.DiffusionKey = bitxor(k, ktemp);
            
            % Apply diffusion
            timg_flat = app.EncryptedImage(:)';
            himg_flat = bitxor(uint8(app.DiffusionKey), uint8(timg_flat));
            app.EncryptedImage = reshape(himg_flat, [row, col]);
            
            imshow(app.EncryptedImage, 'Parent', app.AdminImageAxes);
            app.AdminImageAxes.Title.String = 'Final Encrypted Image';
            drawnow;
            figure(app.UIFigure); % Keep focus
            pause(1); % Increased from 0.5 to 1 second (0.5x speed)
        end

        function GenerateKeyButtonPushed(app, ~)
            % Generate 256-digit key
            rng('shuffle'); % Ensure randomness
            app.GeneratedKey = '';
            for i = 1:256
                app.GeneratedKey = [app.GeneratedKey, num2str(randi([0, 9]))];
            end
            
            app.KeyDisplayArea.Value = app.GeneratedKey;
            app.KeyDisplayArea.Visible = true;
            app.CopyKeyButton.Visible = true;
            app.GenerateKeyButton.Visible = false;
            
            app.AdminStatusLabel.Text = 'Key generated! Copy and share with user.';
            app.UserStatusLabel.Text = 'Ready to decrypt. Enter the key from admin.';
        end

        function CopyKeyButtonPushed(app, ~)
            % Copy key to clipboard
            clipboard('copy', app.GeneratedKey);
            app.AdminStatusLabel.Text = 'Key copied to clipboard!';
        end

        function EnterKeyButtonPushed(app, ~)
            % Validate and start decryption
            if ~app.IsImageUploaded
                uialert(app.UIFigure, 'Please wait for admin to upload and encrypt an image first.', 'No Image Available');
                return;
            end
            
            if isempty(app.GeneratedKey)
                uialert(app.UIFigure, 'Please wait for admin to generate the key first.', 'No Key Available');
                return;
            end
            
            enteredKey = app.KeyInputArea.Value{1};
            if isempty(enteredKey)
                uialert(app.UIFigure, 'Please enter the decryption key.', 'Key Required');
                return;
            end
            
            if ~strcmp(enteredKey, app.GeneratedKey)
                uialert(app.UIFigure, 'Invalid key! Please check and try again.', 'Invalid Key');
                return;
            end
            
            % Start decryption process
            app.startDecryptionProcess();
        end

        function startDecryptionProcess(app)
            app.EnterKeyButton.Enable = false;
            app.UserProgressBar.Visible = true;
            app.UserProgressBar.Text = 'Progress: 0%';
            
            % Step 5: Inverse Diffusion
            app.UserStatusLabel.Text = 'Applying inverse diffusion...';
            app.applyInverseDiffusion();
            app.UserProgressBar.Text = 'Progress: 25%';
            
            % Step 6: Inverse Confusion
            app.UserStatusLabel.Text = 'Applying inverse confusion...';
            app.applyInverseConfusion();
            app.UserProgressBar.Text = 'Progress: 50%';
            
            % Step 7: Display Decrypted Grayscale
            app.UserStatusLabel.Text = 'Displaying decrypted image...';
            imshow(app.DecryptedImage, 'Parent', app.UserImageAxes);
            app.UserImageAxes.Title.String = 'Decrypted Grayscale Image';
            pause(2); % Increased from 1 to 2 seconds (0.5x speed)
            app.UserProgressBar.Text = 'Progress: 75%';
            
            % Step 8: Color Reconstruction
            app.UserStatusLabel.Text = 'Reconstructing color...';
            app.animateColorReconstruction();
            app.UserProgressBar.Text = 'Progress: 100%';
            
            app.UserStatusLabel.Text = 'Decryption completed! Download your image.';
            app.DownloadImageButton.Visible = true;
            app.EnterKeyButton.Enable = true;
        end

        function applyInverseDiffusion(app)
            % Reverse the diffusion process
            himg_flat = app.EncryptedImage(:)';
            timg_decrypted_flat = bitxor(uint8(app.DiffusionKey), uint8(himg_flat));
            temp_img = reshape(timg_decrypted_flat, app.ImageDimensions);
            
            imshow(temp_img, 'Parent', app.UserImageAxes);
            app.UserImageAxes.Title.String = 'After Inverse Diffusion';
            pause(1); % Increased from 0.5 to 1 second (0.5x speed)
        end

        function applyInverseConfusion(app)
            % Apply inverse confusion with animation
            % FIXED: Extract dimensions properly
            row = app.ImageDimensions(1);
            col = app.ImageDimensions(2);
            s = row * col;
            
            himg_flat = app.EncryptedImage(:)';
            timg_decrypted_flat = bitxor(uint8(app.DiffusionKey), uint8(himg_flat));
            timg_decrypted_linear = timg_decrypted_flat(:);
            
            unshuffle_steps = 200; % Increased from 50 to 200 steps for much more precise visualization
            pixels_per_step = ceil(s / unshuffle_steps);
            
            for step = 1:unshuffle_steps
                total_processed = step * pixels_per_step;
                start_idx = max(1, s - total_processed + 1);
                end_idx = s - (step-1) * pixels_per_step;
                end_idx = min(end_idx, s);
                
                % Apply inverse shuffling
                for m = end_idx:-1:start_idx
                    if m >= 1 && m <= s && app.ChaosIndices(m) >= 1 && app.ChaosIndices(m) <= s
                        t1 = timg_decrypted_linear(m);
                        timg_decrypted_linear(m) = timg_decrypted_linear(app.ChaosIndices(m));
                        timg_decrypted_linear(app.ChaosIndices(m)) = t1;
                    end
                end
                
                % Update display more frequently for better visualization
                if mod(step, 10) == 0 || step == unshuffle_steps % Changed from mod 5 to mod 10 for more frequent updates
                    img_inv_confused = reshape(timg_decrypted_linear, [row, col]);
                    imshow(img_inv_confused, 'Parent', app.UserImageAxes);
                    app.UserImageAxes.Title.String = sprintf('Inverse Confusion (%d%%)', round(100*step/unshuffle_steps));
                    drawnow;
                    pause(0.2); % Increased from 0.1 to 0.2 seconds (0.5x speed)
                end
            end
            
            app.DecryptedImage = reshape(timg_decrypted_linear, [row, col]);
        end

        function animateColorReconstruction(app)
            % Animate reconstruction from grayscale to color
            if size(app.OriginalImage, 3) == 3
                steps = 40; % Increased from 20 to 40 steps for more precise visualization
                gray3channel = repmat(app.DecryptedImage, [1, 1, 3]);
                
                for i = 1:steps
                    alpha = i / steps;
                    % Blend from grayscale to color
                    blended = (1-alpha) * double(gray3channel) + alpha * double(app.OriginalImage);
                    imshow(uint8(blended), 'Parent', app.UserImageAxes);
                    app.UserImageAxes.Title.String = sprintf('Color Reconstruction (%d%%)', round(alpha*100));
                    drawnow;
                    pause(0.1); % Increased from 0.05 to 0.1 seconds (0.5x speed)
                end
                app.ReconstructedImage = app.OriginalImage;
            else
                app.ReconstructedImage = app.DecryptedImage;
            end
            
            imshow(app.ReconstructedImage, 'Parent', app.UserImageAxes);
            app.UserImageAxes.Title.String = 'Reconstructed Image';
            pause(1); % Increased from 0.5 to 1 second (0.5x speed)
        end

        function DownloadImageButtonPushed(app, ~)
            % Save the reconstructed image
            [filename, filepath] = uiputfile({'*.png', 'PNG Files'; '*.jpg', 'JPEG Files'}, 'Save Reconstructed Image');
            
            if filename ~= 0
                try
                    imwrite(app.ReconstructedImage, fullfile(filepath, filename));
                    app.UserStatusLabel.Text = 'Image saved successfully!';
                catch ME
                    uialert(app.UIFigure, sprintf('Error saving image: %s', ME.message), 'Save Error');
                end
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 700];
            app.UIFigure.Name = 'Chaos-Based Image Encryption System';
            app.UIFigure.Icon = 'none';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x', '1x'};
            app.GridLayout.RowHeight = {'1x'};

            % Create AdminPanel
            app.AdminPanel = uipanel(app.GridLayout);
            app.AdminPanel.BackgroundColor = [0.94 0.94 0.94];
            app.AdminPanel.Title = '';
            app.AdminPanel.Layout.Row = 1;
            app.AdminPanel.Layout.Column = 1;

            % Create AdminLabel
            app.AdminLabel = uilabel(app.AdminPanel);
            app.AdminLabel.BackgroundColor = [0.2 0.4 0.8];
            app.AdminLabel.HorizontalAlignment = 'center';
            app.AdminLabel.FontSize = 18;
            app.AdminLabel.FontWeight = 'bold';
            app.AdminLabel.FontColor = [1 1 1];
            app.AdminLabel.Position = [10 650 580 40];
            app.AdminLabel.Text = 'ADMIN PANEL - IMAGE ENCRYPTION';

            % Create UploadImageButton
            app.UploadImageButton = uibutton(app.AdminPanel, 'push');
            app.UploadImageButton.ButtonPushedFcn = createCallbackFcn(app, @UploadImageButtonPushed, true);
            app.UploadImageButton.BackgroundColor = [0.3 0.7 0.3];
            app.UploadImageButton.FontSize = 14;
            app.UploadImageButton.FontWeight = 'bold';
            app.UploadImageButton.FontColor = [1 1 1];
            app.UploadImageButton.Position = [200 600 200 40];
            app.UploadImageButton.Text = '�? Upload Image';

            % Create AdminImagePanel
            app.AdminImagePanel = uipanel(app.AdminPanel);
            app.AdminImagePanel.BackgroundColor = [1 1 1];
            app.AdminImagePanel.Position = [20 150 560 430];

            % Create AdminImageAxes
            app.AdminImageAxes = uiaxes(app.AdminImagePanel);
            app.AdminImageAxes.Position = [10 10 540 410];
            app.AdminImageAxes.XTick = [];
            app.AdminImageAxes.YTick = [];

            % Create AdminStatusLabel
            app.AdminStatusLabel = uilabel(app.AdminPanel);
            app.AdminStatusLabel.FontSize = 12;
            app.AdminStatusLabel.FontWeight = 'bold';
            app.AdminStatusLabel.Position = [20 120 560 20];
            app.AdminStatusLabel.Text = 'Ready to upload image...';

            % Create AdminProgressBar
            app.AdminProgressBar = uilabel(app.AdminPanel);
            app.AdminProgressBar.BackgroundColor = [0.2 0.6 0.8];
            app.AdminProgressBar.HorizontalAlignment = 'center';
            app.AdminProgressBar.FontSize = 12;
            app.AdminProgressBar.FontWeight = 'bold';
            app.AdminProgressBar.FontColor = [1 1 1];
            app.AdminProgressBar.Position = [20 90 560 20];
            app.AdminProgressBar.Text = '';
            app.AdminProgressBar.Visible = false;

            % Create GenerateKeyButton
            app.GenerateKeyButton = uibutton(app.AdminPanel, 'push');
            app.GenerateKeyButton.ButtonPushedFcn = createCallbackFcn(app, @GenerateKeyButtonPushed, true);
            app.GenerateKeyButton.BackgroundColor = [0.8 0.4 0.2];
            app.GenerateKeyButton.FontSize = 14;
            app.GenerateKeyButton.FontWeight = 'bold';
            app.GenerateKeyButton.FontColor = [1 1 1];
            app.GenerateKeyButton.Position = [200 50 200 30];
            app.GenerateKeyButton.Text = '🔑 Generate Key';
            app.GenerateKeyButton.Visible = false;

            % Create KeyDisplayArea
            app.KeyDisplayArea = uitextarea(app.AdminPanel);
            app.KeyDisplayArea.Position = [20 10 450 35];
            app.KeyDisplayArea.FontSize = 10;
            app.KeyDisplayArea.Editable = false;
            app.KeyDisplayArea.Visible = false;

            % Create CopyKeyButton
            app.CopyKeyButton = uibutton(app.AdminPanel, 'push');
            app.CopyKeyButton.ButtonPushedFcn = createCallbackFcn(app, @CopyKeyButtonPushed, true);
            app.CopyKeyButton.BackgroundColor = [0.6 0.2 0.8];
            app.CopyKeyButton.FontSize = 12;
            app.CopyKeyButton.FontWeight = 'bold';
            app.CopyKeyButton.FontColor = [1 1 1];
            app.CopyKeyButton.Position = [480 10 100 35];
            app.CopyKeyButton.Text = '📋 Copy';
            app.CopyKeyButton.Visible = false;

            % Create UserPanel
            app.UserPanel = uipanel(app.GridLayout);
            app.UserPanel.BackgroundColor = [0.94 0.94 0.94];
            app.UserPanel.Title = '';
            app.UserPanel.Layout.Row = 1;
            app.UserPanel.Layout.Column = 2;

            % Create UserLabel
            app.UserLabel = uilabel(app.UserPanel);
            app.UserLabel.BackgroundColor = [0.8 0.2 0.2];
            app.UserLabel.HorizontalAlignment = 'center';
            app.UserLabel.FontSize = 18;
            app.UserLabel.FontWeight = 'bold';
            app.UserLabel.FontColor = [1 1 1];
            app.UserLabel.Position = [10 650 580 40];
            app.UserLabel.Text = 'USER PANEL - IMAGE DECRYPTION';

            % Create KeyInputArea
            app.KeyInputArea = uitextarea(app.UserPanel);
            app.KeyInputArea.Position = [20 595 450 35];
            app.KeyInputArea.FontSize = 10;
            app.KeyInputArea.Placeholder = 'Enter 256-digit decryption key here...';

            % Create EnterKeyButton
            app.EnterKeyButton = uibutton(app.UserPanel, 'push');
            app.EnterKeyButton.ButtonPushedFcn = createCallbackFcn(app, @EnterKeyButtonPushed, true);
            app.EnterKeyButton.BackgroundColor = [0.2 0.6 0.8];
            app.EnterKeyButton.FontSize = 14;
            app.EnterKeyButton.FontWeight = 'bold';
            app.EnterKeyButton.FontColor = [1 1 1];
            app.EnterKeyButton.Position = [480 595 100 35];
            app.EnterKeyButton.Text = '🔓 Decrypt';

            % Create UserImagePanel
            app.UserImagePanel = uipanel(app.UserPanel);
            app.UserImagePanel.BackgroundColor = [1 1 1];
            app.UserImagePanel.Position = [20 150 560 430];

            % Create UserImageAxes
            app.UserImageAxes = uiaxes(app.UserImagePanel);
            app.UserImageAxes.Position = [10 10 540 410];
            app.UserImageAxes.XTick = [];
            app.UserImageAxes.YTick = [];

            % Create UserStatusLabel
            app.UserStatusLabel = uilabel(app.UserPanel);
            app.UserStatusLabel.FontSize = 12;
            app.UserStatusLabel.FontWeight = 'bold';
            app.UserStatusLabel.Position = [20 120 560 20];
            app.UserStatusLabel.Text = 'Waiting for admin to upload image...';

            % Create UserProgressBar
            app.UserProgressBar = uilabel(app.UserPanel);
            app.UserProgressBar.BackgroundColor = [0.8 0.2 0.2];
            app.UserProgressBar.HorizontalAlignment = 'center';
            app.UserProgressBar.FontSize = 12;
            app.UserProgressBar.FontWeight = 'bold';
            app.UserProgressBar.FontColor = [1 1 1];
            app.UserProgressBar.Position = [20 90 560 20];
            app.UserProgressBar.Text = '';
            app.UserProgressBar.Visible = false;

            % Create DownloadImageButton
            app.DownloadImageButton = uibutton(app.UserPanel, 'push');
            app.DownloadImageButton.ButtonPushedFcn = createCallbackFcn(app, @DownloadImageButtonPushed, true);
            app.DownloadImageButton.BackgroundColor = [0.2 0.8 0.4];
            app.DownloadImageButton.FontSize = 14;
            app.DownloadImageButton.FontWeight = 'bold';
            app.DownloadImageButton.FontColor = [1 1 1];
            app.DownloadImageButton.Position = [200 50 200 30];
            app.DownloadImageButton.Text = '💾 Download Image';
            app.DownloadImageButton.Visible = false;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ImageEncryptionApp

            % Create UIFigure and components
%             createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before the app is deleted
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end