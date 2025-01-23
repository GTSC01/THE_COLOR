function C = extract_dominant_color(N, method, seka_flag)
% 使用示例：C = extract_dominant_color(8, 'grid', 1);

% 图片主题色自动提取函数（带颜色信息输出）
% 修改内容：增加RGB值显示和详细颜色矩阵输出

% 选择图片文件
[file, path] = uigetfile({'*.jpg;*.png;*.jpeg;*.bmp', 'Image Files'});
if isequal(file, 0)
    error('未选择图片');
end
img = imread(fullfile(path, file));
img = im2double(img);

% 将图像转换为像素颜色矩阵
[h, w, ~] = size(img);
pixels = reshape(img, h*w, 3);

valid_counts = []; % 初始化颜色计数变量

switch lower(method)
    case 'grid' % 九宫格算法（带详细颜色输出）
        bins = 8;% 根据图片分辨率改变
        bin_size = 1 / bins;
        
        indices = floor(pixels / bin_size);
        indices(indices >= bins) = bins-1;
        indices = indices + 1;
        
        linear_idx = indices(:,1) + (indices(:,2)-1)*bins + (indices(:,3)-1)*bins^2;
        counts = accumarray(linear_idx, 1, [bins^3 1]);
        
        [sorted_counts, idx] = sort(counts, 'descend');
        valid_counts = sorted_counts(1:min(N, nnz(counts)));
        
        C = zeros(length(valid_counts), 3);
        for i = 1:length(valid_counts)
            [r, g, b] = ind2sub([bins, bins, bins], idx(i));
            C(i,:) = ([r, g, b] - 0.5) * bin_size;
        end
        
    case 'kmeans' 
        max_samples = 10000;% 根据图片分辨率改变
        if h*w > max_samples
            pixels = pixels(randperm(h*w, max_samples), :);
        end
        
        try
            opts = statset('UseParallel', true);
            [idx, centers] = kmeans(pixels, N, 'Replicates', 3, 'Options', opts);
            C = centers;
            % 计算每个簇的样本数量
            valid_counts = accumarray(idx, 1, [N 1]);
        catch
            warning('K-means失败，改用九宫格法');
            C = extract_dominant_color(N, 'grid', seka_flag);
            return;
        end
        
    otherwise
        error('无效的提取方法');
end

% 按亮度排序颜色（HSV空间）
hsv_colors = rgb2hsv(C);
[~, sort_idx] = sort(hsv_colors(:,3), 'descend');
C = C(sort_idx, :);
if ~isempty(valid_counts)  % 保持颜色计数与排序后的颜色对应
    valid_counts = valid_counts(sort_idx);
end

% 显示完整颜色矩阵
fprintf('\nRGB颜色矩阵（0-1范围）:\n');
disp(C)

% 显示0-255整数格式
C_255 = round(C * 255);
fprintf('\nRGB颜色矩阵（0-255范围）:\n');
disp(C_255)

% 可视化展示（带颜色标注）
if seka_flag
    figure('Name','主题色提取结果','NumberTitle','off', 'Position', [100 100 1000 600])
    
    % 原图显示（增大显示区域）
    subplot('Position', [0.05 0.35 0.9 0.6]) % 调整位置和高度
    imshow(img)
    title('原始图片', 'FontSize', 10)
    
    % 颜色条显示（减小高度）
    subplot('Position', [0.05 0.05 0.9 0.25]) % 调整位置和高度
    hold on
    
    % 计算颜色比例
    if isempty(valid_counts)
        valid_counts = ones(size(C,1), 1); % 默认等宽显示
    end
    proportions = valid_counts / sum(valid_counts);
    percentages = round(proportions * 100, 1); % 计算百分比
    
    current_x = 0;
    for i = 1:size(C,1)
        % 绘制颜色块
        rectangle('Position', [current_x, 0, proportions(i), 1],...
                 'FaceColor', C(i,:), 'EdgeColor', 'none')
        
        % 计算文本颜色对比度
        brightness = 0.2126*C(i,1) + 0.7152*C(i,2) + 0.0722*C(i,3);
        text_color = [1 1 1]; % 白色
        if brightness > 0.6
            text_color = [0 0 0]; % 黑色
        end
        
        % 添加双行标注
        if proportions(i) > 0.15 % 宽色块显示两行
            % 显示RGB值
            text(current_x + proportions(i)/2, 0.7,...
                sprintf('RGB: %d,%d,%d', C_255(i,1), C_255(i,2), C_255(i,3)),...
                'Color', text_color,...
                'HorizontalAlignment', 'center',...
                'VerticalAlignment', 'middle',...
                'FontSize', 8,...
                'FontWeight', 'bold');
            
            % 显示百分比
            text(current_x + proportions(i)/2, 0.3,...
                sprintf('%.1f%%', percentages(i)),...
                'Color', text_color,...
                'HorizontalAlignment', 'center',...
                'VerticalAlignment', 'middle',...
                'FontSize', 9,...
                'FontWeight', 'bold');
        else % 窄色块显示单行
            text(current_x + proportions(i)/2, 0.5,...
                sprintf('%d,%d,%d\n%.1f%%', C_255(i,1), C_255(i,2), C_255(i,3), percentages(i)),...
                'Color', text_color,...
                'HorizontalAlignment', 'center',...
                'VerticalAlignment', 'middle',...
                'FontSize', 7,...
                'FontWeight', 'bold');
        end
        
        current_x = current_x + proportions(i);
    end
    
    axis([0 1 0 1])
    set(gca, 'XTick', [], 'YTick', [])
    title('提取的8种主题色', 'FontSize', 10)
    hold off
    
    % 显示颜色占比（如果数据可用）
    if exist('valid_counts', 'var') && ~isempty(valid_counts)
        total = sum(valid_counts);
        fprintf('\n颜色占比分析:\n')
        for i = 1:length(valid_counts)
            fprintf('颜色%d: %.2f%% \t RGB: [%d, %d, %d]\n',...
                i, valid_counts(i)/total*100, C_255(i,1), C_255(i,2), C_255(i,3));
        end
    end
end
end