#' Generate Distinct Random Colors
#'
#' Generates `k` colors by sampling RGB space and clustering in LAB space.
#'
#' @param k Number of colors to generate.
#' @param seed Random seed for reproducibility.
#'
#' @return An unnamed character vector of hex colors.
#' @export
get_random_colors <- function(k, seed = 10) {
  n <- 2000
  set.seed(seed)
  ourColorSpace <- colorspace::RGB(runif(n), runif(n), runif(n))
  ourColorSpace <- methods::as(ourColorSpace, "LAB")
  km <- kmeans(ourColorSpace@coords, k, iter.max = 20)
  return(unname(colorspace::hex(colorspace::LAB(km$centers))))
}

#' Convert Named Colors to Hex
#'
#' @param rcolor Character vector of R color names.
#'
#' @return A character vector of hex colors.
#' @export
get_hex_color <- function(rcolor) {
  rgbcolor <- grDevices::col2rgb(rcolor)
  grDevices::rgb(rgbcolor[1, ], rgbcolor[2, ], rgbcolor[3, ], maxColorValue = 255)
}

#' Find the Closest Named R Color
#'
#' @param hex A hex color string.
#'
#' @return The closest base R color name. This is a human-friendly
#'   approximation; the input hex value remains the exact color.
#' @export
get_closest_color <- function(hex) {
  target_rgb <- grDevices::col2rgb(hex)
  color_names <- grDevices::colors()
  all_colors_rgb <- grDevices::col2rgb(color_names)
  
  calc_distance <- function(color1, color2) {
    sqrt(sum((color1 - color2)^2))
  }
  
  distances <- apply(all_colors_rgb, 2, function(color) calc_distance(color, target_rgb))
  return(color_names[which.min(distances)])
}

#' Name Hex Colors by Closest R Color
#'
#' @param col Character vector of hex colors.
#'
#' @return A named character vector of hex colors. Each name is the closest
#'   base R color name; each value is the exact hex color.
#' @export
colorvect <- function(col) {
  named_colors <- setNames(col, sapply(col, get_closest_color))
  valid_names <- names(named_colors) %in% grDevices::colors()  # Check for valid color names
  named_colors[valid_names]  # Return only valid names
}

pick_palette <- function(sel_pal, seed = 10){
  # Predefined palettes (custom and Brewer)
  colorlist <- list(
    Default = c("orangered2" = "#f34207",
                "dodgerblue3" = "#2379cc",
                "mediumseagreen" = "#20b465",
                "steelblue1" = "#53c6ef",
                "chocolate1" = "#fd8f20",
                "mediumorchid1" = "#fb57f9",
                "goldenrod1" = "#ffda32",    
                "orchid4" = "#824598",
                "darkseagreen3" = "#aed0a0",
                "deeppink" = "#ff0087",
                "darkgoldenrod4" = "#a0580f",
                "salmon" = "#fe707d",
                "deepskyblue4" = "#116966",
                "darkviolet" = "#9a05cb",
                "greenyellow" = "#9dea19",
                "bisque2" = "#f2cdb9",
                "maroon" = "#b02949",
                "aquamarine2" = "#6becad",
                "royalblue3" = "#324ae4",
                "violet" = "#fd95e8",
                "gray85" = "#D9D9D9",
                "gray70" = "#B3B3B3",
                "gray40" = "#666666",
                "black" = "#000000"),
    Okabeito = c("darkorange3" = "#D55E00",
                 "steelblue2" = "#56B4E9",
                 "cyan4" = "#009E73",
                 "goldenrod1" = "#FFD92F",
                 "dodgerblue3" = "#0072B2",
                 "orange2" = "#E69F00",
                 "pink3" = "#CC79A7",
                 "black" = "#000000")
  )
  
  qual_palettes <- rownames(RColorBrewer::brewer.pal.info[RColorBrewer::brewer.pal.info$category == 'qual', ])
  palette_hex_codes <- list()
  
  for (palette in qual_palettes) {
    max_colors <- RColorBrewer::brewer.pal.info[palette, "maxcolors"]
    palette_hex_codes[[palette]] <- RColorBrewer::brewer.pal(max_colors, palette)
  }
  
  # Combine qualitative palettes
  set.seed(seed)
  qual_col_pals <- RColorBrewer::brewer.pal.info[RColorBrewer::brewer.pal.info$category == 'qual', ]
  combined_qual <- unlist(mapply(RColorBrewer::brewer.pal, qual_col_pals$maxcolors, rownames(qual_col_pals)))
  combined_qual <- base::sample(unique(combined_qual))
  palette_hex_codes[["Qualitative"]] <- combined_qual
  
  x <- lapply(palette_hex_codes, function(x) colorvect(x))
  
  # Get palettes from ggsci
  color_sci <- list(
    NPG_1 = ggsci::pal_npg("nrc", alpha = 1)(10),
    NPG_2 = ggsci::pal_npg("nrc", alpha = 0.7)(10),
    AAAS_1 = ggsci::pal_aaas("default", alpha = 1)(10),
    AAAS_2 = ggsci::pal_aaas("default", alpha = 0.7)(10),
    NEJM_1 = ggsci::pal_nejm("default", alpha = 1)(8),
    NEJM_2 = ggsci::pal_nejm("default", alpha = 0.7)(8),
    Lancet_1 = ggsci::pal_lancet("lanonc", alpha = 1)(9),
    Lancet_2 = ggsci::pal_lancet("lanonc", alpha = 0.7)(9),
    JAMA_1 = ggsci::pal_jama("default", alpha = 1)(7),
    JAMA_2 = ggsci::pal_jama("default", alpha = 0.7)(7),
    JCO_1 = ggsci::pal_jco("default", alpha = 1)(10),
    JCO_2 = ggsci::pal_jco("default", alpha = 0.7)(10),
    UCSCGB_1 = ggsci::pal_ucscgb("default", alpha = 1)(26),
    UCSCGB_2 = ggsci::pal_ucscgb("default", alpha = 0.7)(26)
  )
  
  y <- lapply(color_sci, function(x) colorvect(x))
  colorlist <- c(colorlist, x, y)
  return(colorlist[[sel_pal]])
}



#' Get Colors From a Named Palette
#'
#' Returns a palette and extends it with generated colors when more colors are
#' requested than the source palette contains.
#'
#' @param num_col Number of colors to return.
#' @param sel_pal Name of the selected palette.
#' @param seed Random seed for reproducibility.
#'
#' @return A list with `colors` and `palette_size`.
#' @export
get_colors <- function(num_col, sel_pal, seed = 10) {
  colors <- pick_palette(sel_pal)
  if (is.null(colors)) {
    stop("Unknown palette: ", sel_pal)
  }
  # If the palette has fewer colors than needed, generate additional colors.
  m <- length(colors)
  if (m < num_col) {
    l <- num_col - m
    categ_colors <- get_random_colors(l,seed)
    colornames <- sapply(categ_colors, get_closest_color)
    new_colors <- setNames(names(colornames), colornames)
    selected_colors <- c(colors, new_colors)
  } else {
    selected_colors <- colors
  }
  
  if (length(selected_colors) > num_col) {
    selected_colors <- selected_colors[1:num_col]  # Truncate excess colors
  } else if (length(selected_colors) < num_col) {
    missing_colors <- num_col - length(selected_colors)
    new_colors <- get_random_colors(missing_colors, seed)
    selected_colors <- c(selected_colors, new_colors)  # Fill missing colors
  }
  return(list(colors = selected_colors, palette_size = m))
}



#' Plot a Color Palette
#'
#' @param colors Character vector of colors to display.
#' @param n_colors Number of colors to plot.
#' @param split_columns Logical indicating whether to split into two columns.
#' @param label_colors Logical indicating whether to label colors.
#' @param title Optional plot title.
#'
#' @return Invisibly returns `NULL` after drawing the plot.
#' @export
plot_palette <-
  function(colors,
           n_colors,
           split_columns,
           label_colors = TRUE,
           title = NULL) {
    # Function to calculate greyscale value for text color contrast
    .greyscale <- function(col) {
      col <- grDevices::col2rgb(col)
      sum(col * c(0.299, 0.587, 0.114)) / 255
    }
    # Function to calculate font size depending on the number of requested colors
    .fontsize <-
      function(n_colors,
               n_breaks = c(0, 40, 75, Inf),
               decrease_rates = c(0.6, 0.65, 0.75),
               min_fontsize = 0.3,
               max_fontsize = 10) {
        decrease <-
          cut(n_colors,
              breaks = n_breaks,
              labels = decrease_rates,
              right = FALSE)
        decrease <- as.numeric(as.character(decrease))
        fontsize <- max_fontsize / (n_colors ^ decrease)
        max(min(fontsize, max_fontsize), min_fontsize)
      }
    
    # Determine whether to split into two columns and set plot dimensions
    do_split <- split_columns & n_colors > 1
    plot_width <- ifelse(do_split, 2, 1)
    half_colors <- ceiling(n_colors / 2)
    plot_height <- ifelse(do_split, half_colors, n_colors)
    
    # Set up the plot area
    plot(
      1,
      type = "n",
      xlim = c(0, plot_width),
      ylim = c(0, plot_height),
      xaxt = 'n',
      yaxt = 'n',
      xlab = "",
      ylab = ""
    )
    if (!is.null(title)) {
      title(main = title, adj = 0.5)
    }
    
    # Draw the palette
    for (i in 1:n_colors) {
      # Calculate coordinates
      if (do_split) {
        rect_x1 <- ifelse(i <= half_colors, 0, 1)
        rect_y1 <-
          ifelse(rect_x1 == 0, plot_height - i, plot_height - (i - half_colors))
        labels_size <- if (half_colors > 4) {
          .fontsize(
            n_colors = half_colors,
            n_breaks = c(0, 40, 75, Inf),
            decrease_rates = c(0.7, 0.65, 0.75),
            min_fontsize = 0.45,
            max_fontsize = 10
          )
        } else {
          3
        }
      } else {
        rect_x1 <- 0
        rect_y1 <- plot_height - i
        labels_size <-
          .fontsize(
            n_colors = n_colors,
            n_breaks = c(0, 40, 75, Inf),
            decrease_rates = c(0.6, 0.65, 0.75),
            min_fontsize = 0.45,
            max_fontsize = 10
          )
      }
      rect_x2 <- rect_x1 + 1
      rect_y2 <- rect_y1 + 1
      if(label_colors){
        labels <- names(colors)[i]
      } else {
        labels = rep("", n_colors)
      }
      labels_color <-
        ifelse(.greyscale(colors[i]) > 0.5, "black", "white")
      
      # Draw the rectangles
      rect(rect_x1,
           rect_y1,
           rect_x2,
           rect_y2,
           col = colors[i],
           border = "black")
      text((rect_x1 + rect_x2) / 2,
           (rect_y1 + rect_y2) / 2,
           labels,
           cex = labels_size,
           col = labels_color
      )
    }
  }
