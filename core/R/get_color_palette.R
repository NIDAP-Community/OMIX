#' Generate and Plot a Color Palette
#'
#' This function generates a color palette based on user-specified parameters,
#' including options for using a custom palette. It will also plot the palette.
#'
#' @param num_col Number of colors needed.
#' @param sel_pal The name of the selected palette.
#' @param use_custom_pal Logical flag for custom palette usage.
#' @param custom_pal A vector of custom colors.
#' @param split_pal_plot Logical for splitting the palette plot into columns.
#' @param seed Random seed for reproducibility.
#' @param print Whether to display the plot.
#'
#' @return A named vector of color hex codes. Names are the closest base R
#'   color names, which provide a convenient R-friendly label; the hex values
#'   remain the exact colors used.
#' @export
#'
#' @examples
#' \dontrun{
#'   get_color_palette(10, "Default", FALSE, c(), TRUE)
#' }

get_color_palette <- function(num_col = 10, 
                            sel_pal = "Default",
                            use_custom_pal = FALSE, 
                            custom_pal = c(), 
                            split_pal_plot = TRUE, 
                            seed = 10, 
                            print = FALSE) {

  if (use_custom_pal) {
    palette_size <- length(custom_pal)
    if (palette_size < num_col) {
      net_color_length <- num_col - palette_size
      new_cols <- get_random_colors(net_color_length, seed)
      hex_palette <- get_hex_color(custom_pal)
      color_list <- colorvect(c(hex_palette, new_cols))
    } else {
      color_list <- colorvect(get_hex_color(custom_pal))
    }
    sel_pal <- "Custom Palette"
  } else {
    palette <- get_colors(num_col, sel_pal, seed)
    color_list <- palette$colors
    palette_size <- palette$palette_size
  }
  
  # Ensure exactly `num_col` colors are returned
  if (length(color_list) < num_col) {
    missing_colors <- num_col - length(color_list)
    new_colors <- get_random_colors(missing_colors, seed)
    color_list <- c(color_list, new_colors)
  } else {
    color_list <- color_list[1:num_col]
  }
  
  if (length(color_list) != num_col) {
    stop("Number of requested colors does not equal the number of colors in the output palette\n")
  } else {
    cat(sprintf("%g: %s %s\n", 1:num_col, names(color_list), color_list), sep = "")
  }
  
  if (print) {
    if(num_col > palette_size){
      title <- sprintf("%s Palette contains %s colors out of %s requested", 
                       sel_pal, palette_size, num_col)
      } else {
      title <- sprintf("%s Palette contains %s colors, providing %s colors as requested", 
                       sel_pal, palette_size, num_col)
      }
    plot_palette(colors = color_list, split_columns = split_pal_plot, n_colors = num_col, 
                label_colors = TRUE, title = title)
  }
  
  return(color_list)
}
